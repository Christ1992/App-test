// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#include "tensorflow_utils.h"
#include "ios_image_load.h"
using tensorflow::Tensor;
using tensorflow::Status;
using tensorflow::string;
using tensorflow::int32;
using tensorflow::uint8;

#include <pthread.h>
#include <unistd.h>
#include <fstream>
#include <queue>
#include <sstream>
#include <string>

namespace {

// Helper class used to load protobufs efficiently.
class IfstreamInputStream : public ::google::protobuf::io::CopyingInputStream {
 public:
  explicit IfstreamInputStream(const std::string& file_name)
      : ifs_(file_name.c_str(), std::ios::in | std::ios::binary) {}
  ~IfstreamInputStream() { ifs_.close(); }

  int Read(void* buffer, int size) {
    if (!ifs_) {
      return -1;
    }
    ifs_.read(static_cast<char*>(buffer), size);
    return ifs_.gcount();
  }

 private:
  std::ifstream ifs_;
};
}  // namespace
static NSString* model_file_name = @"strip_unused_nodes_graph";//@"multibox_model"; frozen
static NSString* model_file_type = @"pb";


bool PortableReadFileToProto(const std::string& file_name,
                             ::google::protobuf::MessageLite* proto) {
  ::google::protobuf::io::CopyingInputStreamAdaptor stream(
      new IfstreamInputStream(file_name));
  stream.SetOwnsCopyingStream(true);
  ::google::protobuf::io::CodedInputStream coded_stream(&stream);
  // Total bytes hard limit / warning limit are set to 1GB and 512MB
  // respectively.
  coded_stream.SetTotalBytesLimit(1024LL << 20, 512LL << 20);
  return proto->ParseFromCodedStream(&coded_stream);
}


// load file from local path
NSString* FilePathForResourceName(NSString* name, NSString* extension) {
    NSString* file_path =
      [[NSBundle mainBundle] pathForResource:name ofType:extension];
  if (file_path == NULL) {
    LOG(FATAL) << "Couldn't find '" << [name UTF8String] << "."
               << [extension UTF8String] << "' in bundle.";
    return nullptr;
  }
  return file_path;
}

// load the model
tensorflow::Status LoadModel(NSString* file_name, NSString* file_type,
                             std::unique_ptr<tensorflow::Session>* session) {
  tensorflow::SessionOptions options;

  tensorflow::Session* session_pointer = nullptr;
  tensorflow::Status session_status =
      tensorflow::NewSession(options, &session_pointer);
  
    if (!session_status.ok()) {
    LOG(ERROR) << "Could not create TensorFlow Session: " << session_status;
    return session_status;
  }
  session->reset(session_pointer);

  tensorflow::GraphDef tensorflow_graph;

  // load the model with file name
  NSString* model_path = FilePathForResourceName(file_name, file_type);
  if (!model_path) {
    LOG(ERROR) << "Failed to find model proto at" << [file_name UTF8String]
               << [file_type UTF8String];
    return tensorflow::errors::NotFound([file_name UTF8String],
                                        [file_type UTF8String]);
  }
  const bool read_proto_succeeded =
      PortableReadFileToProto([model_path UTF8String], &tensorflow_graph);
  if (!read_proto_succeeded) {
    LOG(ERROR) << "Failed to load model proto from" << [model_path UTF8String];
    return tensorflow::errors::NotFound([model_path UTF8String]);
  }

  // create session
  tensorflow::Status create_status = (*session)->Create(tensorflow_graph);
  if (!create_status.ok()) {
    LOG(ERROR) << "Could not create TensorFlow Graph: " << create_status;
    return create_status;
  }
    

  return tensorflow::Status::OK();
}

std::string line;

// load labels
tensorflow::Status LoadLabels(NSString* file_name, NSString* file_type,
                              std::vector<std::string>* label_strings) {
  
  // Read the label list
  NSString* labels_path = FilePathForResourceName(file_name, file_type);
  if (!labels_path) {
    LOG(ERROR) << "Failed to find model proto at" << [file_name UTF8String]
               << [file_type UTF8String];
    return tensorflow::errors::NotFound([file_name UTF8String],
                                        [file_type UTF8String]);
  }
  std::ifstream t;
  t.open([labels_path UTF8String]);
  
  while (t) {
    std::getline(t, line);
    label_strings->push_back(line);
  }
  t.close();
  return tensorflow::Status::OK();
}


// get tensor from resized image
Status ReadTensorFromImageFile(const string& file_name, const int input_height, const int input_width,
                               int *width, int *height, int *channels,
                               int typeFlag,
                               std::vector<Tensor>* out_tensors) {
    
    const int wanted_channels = 3;
    
    std::vector<tensorflow::uint8> original_image_data;
    std::vector<tensorflow::uint8> image_data;
    
    int image_width, image_height, image_channels;
    LoadImageFromFileAndScale(file_name.c_str(), image_width, image_height, image_channels,
                                        input_width, input_height,
                                        &original_image_data, &image_data);
    
    *width = image_width; *height = image_height; *channels = image_channels;

    // tensor of resized image
    tensorflow::Tensor resized_tensor(
                                      tensorflow::DT_FLOAT,
                                      tensorflow::TensorShape({1, input_height, input_width, wanted_channels}));
    auto image_tensor_mapped = resized_tensor.tensor<float, 4>();
    
    //change scaled image data to float and normalize
    tensorflow::uint8* in = image_data.data();
    float* out = image_tensor_mapped.data();
    for (int y = 0; y < input_height; ++y) {
        tensorflow::uint8* in_row = in + (y * input_width * image_channels);
        float* out_row = out + (y * input_width * wanted_channels);
        for (int x = 0; x < input_width; ++x) {
            tensorflow::uint8* in_pixel = in_row + (x * image_channels);
            float* out_pixel = out_row + (x * wanted_channels);
            for (int c = 0; c < wanted_channels; ++c) {
                out_pixel[c] = in_pixel[c];
            }
        }
    }

    
    // tensor of larger resized image
    tensorflow::Tensor image_tensors_org(
                                    tensorflow::DT_UINT8,
                                    tensorflow::TensorShape(
                                                            {1, input_height*2, input_width*2, wanted_channels}));
   auto image_tensor_org_mapped = image_tensors_org.tensor<uint8, 4>();
    in = original_image_data.data();;
    uint8 *c_out = image_tensor_org_mapped.data();
    
    //    get resized pixels
    for (int y = 0; y < input_height*2; ++y) {

        uint8* out_row = c_out + (y * input_width*2 * wanted_channels);
        for (int x = 0; x < input_width*2; ++x) {
            const int in_x = (x * image_width) / (input_width*2);
            const int in_y = (y * image_height) / (input_height*2);
            tensorflow::uint8 *in_pixel =in+in_y*image_width*image_channels+ in_x * image_channels;
            
            uint8 *out_pixel = (out_row + (x * wanted_channels));
            
            for (int c = 0; c < wanted_channels; ++c) {
                 out_pixel[c] = in_pixel[c];
            }
            
        }
    }

    out_tensors->push_back(resized_tensor);
    out_tensors->push_back(image_tensors_org);
    
    
    return Status::OK();
}

// run the detection model
int runModel(NSString* file_name, NSString* file_type,
              int *width, int *height, int *channels,int typeFlag,
              std::vector<tensorflow::Tensor>& outputs)
{
    string image_path = [[NSString stringWithFormat:@"%@/Documents/%@.jpg",NSHomeDirectory(),@"photo"] UTF8String];

    string graph = [FilePathForResourceName(model_file_name, model_file_type) UTF8String];
    
    int32 input_width = 300;
    int32 input_height = 300;
    
    // load and initialize the model.
    std::unique_ptr<tensorflow::Session> session;
    
    Status load_graph_status = LoadModel(model_file_name,model_file_type,
                                         &session);
    if (!load_graph_status.ok()) {
        LOG(ERROR) << load_graph_status;
        return -1;
    }
    
    int image_width;
    int image_height;
    int image_channels;
    
    std::vector<Tensor> image_tensors;
   
    // get the tensor
    Status read_tensor_status = ReadTensorFromImageFile(image_path, input_height, input_width,
                                                        &image_width, &image_height, &image_channels,
                                                        typeFlag,&image_tensors);
    if (!read_tensor_status.ok()) {
        LOG(ERROR) << read_tensor_status;
        return -1;
    }
    const Tensor& resized_tensor = image_tensors[1];
    
    // Actually run the image through the model.
    double a = CFAbsoluteTimeGetCurrent();
    
    Status run_status = session->Run({{"image_tensor", resized_tensor}},
                 {"detection_boxes", "detection_scores", "detection_classes", "num_detections"}, {}, &outputs);
    if (!run_status.ok()) {
        LOG(ERROR) << "Running model failed: " << run_status;
        return -1;
    }
    
    // print run model time
    double b = CFAbsoluteTimeGetCurrent();
    unsigned int m = ((b-a) * 1000.0f); // convert from seconds to milliseconds
    NSLog(@"%@: %d ms", @"Run Model Time taken", m);
    
    //output data
    tensorflow::TTypes<float>::Flat scores_flat = outputs[1].flat<float>();
    std::vector<float> v_scores;
    for(int i=0; i<10; i++)
        v_scores.push_back(scores_flat(i));
    
    *width = image_width;
    *height = image_height;
    *channels = image_channels;
    
    
    return 0;
}
