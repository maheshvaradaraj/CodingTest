//
//  document_catcher.hpp
//  DocumentCropper
//
//  Created by Denis Silko on 1/12/19.
//  Copyright © 2019 Paycasso. All rights reserved.
//

#ifndef document_catcher_hpp
#define document_catcher_hpp

#include <iostream>
#include <ctime>
#include <opencv2/imgproc.hpp>
#include <opencv2/objdetect/objdetect.hpp>
#include "document_detector.hpp"

namespace dc {
    
    struct DocumentCatcherResult {
        cv::Mat document;
        bool pass;
    };
    
    struct DocumentCatcherJSResult {
        int *src;
        int cols;
        int rows;
        int channels;
        bool pass;
    };
    
    class DocumentCatcher {
        
    public:
        DocumentCatcher();
        DocumentCatcher(const std::string cascadePath);
        
        DocumentCatcherResult catchDocument(const cv::Mat &src, const DocumentDetectorResult, const ExpectedDocument, const bool detectFace, const bool automatic = true);
        DocumentCatcherJSResult catchDocument(int *src, int cols, int rows, int channels, const DocumentDetectorResult, const ExpectedDocument, const bool detectFace, const bool automatic = true);
        bool catchDocument(const cv::Mat &src, cv::Mat &document, const ExpectedDocument, const PredictedAccuracy, const bool detectFace = false);
        cv::Mat crop(const cv::Mat &src, const DocumentDetectorResult);
        
        void reset();
        
    private:
        
        bool crop(const cv::Mat &src, cv::Mat &dst, const std::vector<cv::Point> &corners, const cv::Size &cropSize);
        bool detectFace(const cv::Mat &src, const ExpectedDocument expectedDocument);
        double computeBlurriness(const cv::Mat &src);
        
        cv::CascadeClassifier faceCascade_;
        
        size_t bestFrameCount_;
        size_t goodFramesCount_;
        
        size_t goodGradientCount_, badGradientCount_;
        size_t iterator_;
        double lastGradient_;
        double lastTickCount_;
        double captureDuration_;
        
        double minGradient_, maxGradient_;
        double maxGradientAr_;
        
        bool flip_;

        cv::Mat bmu_;
        
        // Delta Time
        clock_t oldTime_;
        double lastDeltaGradient_;
    };
    
}

#endif /* document_catcher_hpp */
