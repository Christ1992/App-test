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
//#include "ios_image_load.h"
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


//tensorflow::Status LoadMemoryMappedModel(}

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

//replacement of GettopN, runModel 调用，runmodel又是View controller里面调用的
tensorflow::Status PrintTopDetections(std::vector<Tensor>& outputs,
                          std::vector<float>& boxScore,
                          std::vector<float>& boxRect,
                          std::vector<string>& boxName,
                          Tensor* original_tensor,
                                      std::vector<string>& labels) {
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
//    
////    如何替换成label？输入带上label就好
//    object_detection::protos::StringIntLabelMap imageLabels;
//    LoadLablesFile([FilePathForResourceName(@"mscoco_label_map", @"txt") UTF8String], &imageLabels);
//    
//    
//    for (int pos = 0; pos < 20; ++pos) {
//        const int label_index = (int32)indices_flat(pos);
//        const float score = scores_flat(pos);
//        
//        if (score < 0.35) break;
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
//
//    }
    
    return Status::OK();
}


//是否在这运行runModel，还是controller里运行？
//int runModel(NSString* file_name, NSString* file_type,
//void ** image_data, int *width, int *height, int *channels,
//std::vector<float>& boxScore,
//std::vector<float>& boxRect,
//std::vector<string>& boxName,
////added labels
//std::vector<string>& labels)
//{







//备选函数：
//1.int GetDisplayName(const object_detection::protos::StringIntLabelMap* labels, string &displayName, int index){...}



// Given an image file name, read in the data, try to decode it as an image,
// resize it to the requested size, and then scale the values as desired. 通过文件名读取数据，载入tensor，resize后，返回tensor？

//2. Status ReadTensorFromImageFile(const string& file_name, const int input_height, const int input_width,
//                               int *width, int *height, int *channels,
//                               const float input_mean, const float input_std,
//                               std::vector<Tensor>* out_tensors) {
//}

