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

NSString* FilePathForResourceName(NSString* name, NSString* extension) {
    //    fileFullpath=[NSString initWithFormat:@"%s/%s", doucumentDirectory, name ];
    NSString* file_path =
      [[NSBundle mainBundle] pathForResource:name ofType:extension];
  if (file_path == NULL) {
    LOG(FATAL) << "Couldn't find '" << [name UTF8String] << "."
               << [extension UTF8String] << "' in bundle.";
    return nullptr;
  }
  return file_path;
}

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

  tensorflow::Status create_status = (*session)->Create(tensorflow_graph);
  if (!create_status.ok()) {
    LOG(ERROR) << "Could not create TensorFlow Graph: " << create_status;
    return create_status;
  }
    

  return tensorflow::Status::OK();
}

std::string line;
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

static NSString* model_file_name = @"eight_calculaiton_graph";//@"multibox_model"; frozen
static NSString* model_file_type = @"pb";
Status ReadTensorFromImageFile(const string& file_name, const int input_height, const int input_width,
                               int *width, int *height, int *channels,
                               int typeFlag,
                               std::vector<Tensor>* out_tensors) {
    
    const int wanted_channels = 3;
    
    std::vector<tensorflow::uint8> original_image_data;
    std::vector<tensorflow::uint8> image_data;
    
    int image_width, image_height, image_channels;
    int ret = LoadImageFromFileAndScale(file_name.c_str(), image_width, image_height, image_channels,
                                        input_width, input_height,
                                        &original_image_data, &image_data);
    
    *width = image_width; *height = image_height; *channels = image_channels;
//    assert(image_channels >= wanted_channels && ret == 0);
    
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

//    if(typeFlag==3){
//        image_channels=3;
//    }else{
//        image_channels=4;
//    };
    NSLog(@"readTensor:%d",typeFlag);
     NSLog(@"image_channels:%d",image_channels);
        
    
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
//
//    tensorflow::Tensor image_tensors_org4(
//                                          tensorflow::DT_UINT8,
//                                          tensorflow::TensorShape({1, image_height, image_width, image_channels}));
//    
//    auto image_tensor_org4_mapped = image_tensors_org4.tensor<uint8, 4>();
//    memcpy(image_tensor_org4_mapped.data(), original_image_data.data(), image_height*image_width*image_channels);
    
    out_tensors->push_back(resized_tensor);
    out_tensors->push_back(image_tensors_org);
//    out_tensors->push_back(image_tensors_org4);
    
    //#endif
    
    
    
    
    
    return Status::OK();
}

int runModel(NSString* file_name, NSString* file_type,
              int *width, int *height, int *channels,int typeFlag,
//             std::vector<float>& boxScore,
//             std::vector<float>& boxRect,
//             std::vector<string>& boxName)
              std::vector<tensorflow::Tensor>& outputs)
{
    string image_path = [[NSString stringWithFormat:@"%@/Documents/%@.jpg",NSHomeDirectory(),@"photo"] UTF8String];
//    [FilePathForResourceName(file_name, file_type) UTF8String];
    string graph = [FilePathForResourceName(model_file_name, model_file_type) UTF8String];
    //string box_priors = [FilePathForResourceName(labels_file_name, labels_file_type) UTF8String];
    
    int32 input_width = 300;
    int32 input_height = 300;
    
    // First we load and initialize the model.
    std::unique_ptr<tensorflow::Session> session;
    //string graph_path = tensorflow::io::JoinPath(root_dir, graph);
    Status load_graph_status = LoadModel(model_file_name,model_file_type,
                                         &session);
    if (!load_graph_status.ok()) {
        LOG(ERROR) << load_graph_status;
        return -1;
    }
    
    int image_width;
    int image_height;
    int image_channels;
    //const int wanted_channels = 3;
    
    // Get the image from disk as a float array of numbers, resized and normalized
    // to the specifications the main graph expects.
    std::vector<Tensor> image_tensors;
    //string image_path = tensorflow::io::JoinPath(root_dir, image);
    
    Status read_tensor_status = ReadTensorFromImageFile(image_path, input_height, input_width,
                                                        &image_width, &image_height, &image_channels,
                                                        typeFlag,&image_tensors);
    if (!read_tensor_status.ok()) {
        LOG(ERROR) << read_tensor_status;
        return -1;
    }
    const Tensor& resized_tensor = image_tensors[1];
    
        // Actually run the image through the model.
//    std::vector<Tensor> outputs;
    double a = CFAbsoluteTimeGetCurrent();
    
    Status run_status =
    //    session->Run({{input_layer, resized_tensor}},
    //                 {output_score_layer, output_location_layer}, {}, &outputs);
    session->Run({{"image_tensor", resized_tensor}},
                 {"detection_boxes", "detection_scores", "detection_classes", "num_detections"}, {}, &outputs);
    if (!run_status.ok()) {
        LOG(ERROR) << "Running model failed: " << run_status;
        return -1;
    }
    
    double b = CFAbsoluteTimeGetCurrent();
    unsigned int m = ((b-a) * 1000.0f); // convert from seconds to milliseconds
    NSLog(@"%@: %d ms", @"Run Model Time taken", m);
    
    tensorflow::TTypes<float>::Flat scores_flat = outputs[1].flat<float>();
    std::vector<float> v_scores;
    for(int i=0; i<10; i++)
        v_scores.push_back(scores_flat(i));
    
//    Status print_status = PrintTopDetections(outputs,
//                                             boxScore, boxRect, boxName,
//                                             &image_tensors[2]);
//    
//    if (!print_status.ok()) {
//        LOG(ERROR) << "Running print failed: " << print_status;
//        return -1;
//    }
    
    //SaveImageFromRawData(image_out, image_tensors[2].tensor<uint8, 4>().data(), image_width, image_height, 4);
//    *image_data = malloc(image_width*image_height*image_channels+8192);
//    memcpy(*image_data, image_tensors[2].tensor<uint8, 4>().data(), image_width*image_height*image_channels);
    //*image_data = image_tensors[2].tensor<uint8, 4>().data();
    *width = image_width;
    *height = image_height;
    *channels = image_channels;
    
    
    return 0;
}
Status PrintTopDetections(std::vector<Tensor>& outputs,
                          std::vector<float>& boxScore,
                          std::vector<float>& boxRect,
                          std::vector<string>& boxName,
                          Tensor* original_tensor) {
//    std::vector<float> locations;
//    //size_t label_count;
//    
//    
//    Tensor &indices = outputs[2];
//    Tensor &scores = outputs[1];
//    
//    tensorflow::TTypes<float>::Flat scores_flat = scores.flat<float>();
//    
//    tensorflow::TTypes<float>::Flat indices_flat = indices.flat<float>();
//    
//    const Tensor& encoded_locations = outputs[0];
//    auto locations_encoded = encoded_locations.flat<float>();
//    
//    LOG(INFO) << original_tensor->DebugString();
//    const int image_width = (int)original_tensor->shape().dim_size(2);
//    const int image_height = (int)original_tensor->shape().dim_size(1);
//    
//    //    tensorflow::TTypes<uint8>::Flat image_flat = original_tensor->flat<uint8>();
//    //    LOG(INFO) << original_tensor->DebugString();
//    
//    object_detection::protos::StringIntLabelMap imageLabels;
//    LoadLablesFile([FilePathForResourceName(@"kid_new_label_map", @"txt") UTF8String], &imageLabels);
//    
//    
//    for (int pos = 0; pos < 20; ++pos) {
//        const int label_index = (int32)indices_flat(pos);
//        const float score = scores_flat(pos);
//        
//        if (score < 0.25) break;
//        
//        float left = locations_encoded(pos * 4 + 1) * image_width;
//        float top = locations_encoded(pos * 4 + 0) * image_height;
//        float right = locations_encoded(pos * 4 + 3) * image_width;
//        float bottom = locations_encoded((pos * 4 + 2)) * image_height;
//        
//        string displayName = "";
//        GetDisplayName(&imageLabels, displayName, label_index);
//        
//        LOG(INFO) << "Detection " << pos << ": "
//        << "L:" << left << " "
//        << "T:" << top << " "
//        << "R:" << right << " "
//        << "B:" << bottom << " "
//        << "(" << pos << ") score: " << score << " Detected Name: " << displayName;
//        
//        boxScore.push_back(score);
//        boxName.push_back(displayName);
//        boxRect.push_back(left); boxRect.push_back(top); boxRect.push_back(right); boxRect.push_back(bottom);
//        
//        //DrawBox(image_width, image_height, left, top, right, bottom, &image_flat);
//    }
//    
    return Status::OK();
}
