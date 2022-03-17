//
//  document_detector.hpp
//  cropper
//
//  Created by Denis Silko on 1/6/19.
//

#ifndef document_detector_hpp
#define document_detector_hpp

#include <iostream>
#include <opencv2/imgproc.hpp>

namespace dc {
    
    enum PointAxis {X = 0, Y};
    enum LineOrientation {VERTICAL, HORIZONTAL};
    enum ExpectedDocumentOrientation {LANDSCAPE, PORTRAIT};
    
    enum PredictedAccuracy {
        PA_1, // BMU Candidate
        PA_2,
        PA_NONE
    };
    
    enum ExpectedDocument {
        PASSPORT,  // Passport MRTD
        ID,        // Most banking cards and ID cards
        FRENCH_ID, // French, Visas and other ID cards
        GREEN_BOOK,
        LETTER,
        A4
    };
    
    enum DebugDrawType {
        ROI,
        LINES,
        ORIENTED_LINES,
        CLASSIFIED_LINES,
        BEST_LINES,
        PREVIEW,
        CROP,
        ALL
    };
    
    struct DCSize {
        int width;
        int height;
    };
    
    struct DCPoint {
        int x;
        int y;
    };

    struct DocumentDetectorResult {
        std::vector<cv::Point> cropPoints;
        DCSize cropSize;
        bool flip;
        
        DCPoint tl;
        DCPoint tr;
        DCPoint br;
        DCPoint bl;
        
        PredictedAccuracy predictedAccuracy;
    };
    
    class DocumentDetector {
        
    public:
        DocumentDetector(const bool flip = false);
        ~DocumentDetector();

        /*
         quadranglePoints[0] = top left     // A
         quadranglePoints[1] = top right    // B
         quadranglePoints[2] = bottom right // C
         quadranglePoints[3] = bottom left  // D
         */
        
        DocumentDetectorResult detect(const cv::Mat &src, const ExpectedDocument, const ExpectedDocumentOrientation);
        DocumentDetectorResult detect(int *src, int cols, int rows, int channels, const ExpectedDocument, const ExpectedDocumentOrientation);
        
        bool detect(const cv::Mat &src, const ExpectedDocument, const ExpectedDocumentOrientation, std::vector<cv::Point> &, cv::Size &, PredictedAccuracy &);
        bool detect(const cv::Mat &src, std::vector<cv::Point> &quadranglePoints, const float expectAspectRatio, const ExpectedDocumentOrientation, cv::Size &cropSize, PredictedAccuracy &, cv::Mat &debug, const DebugDrawType = ALL, const bool show = false);
        
        void reset();
        
        void setMinFocusDistance(const float minFocusDistance);
        void setMinHorizontalLineLenght(const float minLineLenght);
        void setAngleDeviationRange(const float angleDeviationRange);
        void setLsdMode(const cv::LineSegmentDetectorModes mode);
        void setScale(const double scale);
        void setSigmaScale(const double sigmaScale);
        void setQuant(const double quant);
        void setAngleThreshold(const double angleThreshold);
        void setLogEps(const double logEps);
        void setDensityThreshold(const double densityThreshold);
        void setBinsCount(const int binsCount);
        
        cv::LineSegmentDetectorModes getLsdMode() const;
        float getMinHorizontalLineLenght() const;
        double getScale() const;
        double getSigmaScale() const;
        double getQuant() const;
        double getAngleThreshold() const;
        double getLogEps() const;
        double getDensityThreshold() const;
        int getBinsCount() const;
        
        float getAspectRatioFromExpectedDocument(const ExpectedDocument) const;
        
        cv::Mat crop(const cv::Mat &src, const DocumentDetectorResult);
        bool crop(const cv::Mat &src, cv::Mat &dst, const std::vector<cv::Point> &corners, const cv::Size &cropSize);
        
        void drawQuadrangle(cv::Mat &src, const std::vector<cv::Point> &quadranglePoints, const cv::Scalar &color, const int thickness = 2);
        
    private:
        
        
        
        
        void orientedLines(const std::vector<cv::Vec4f> &lines,
                                 std::vector<cv::Vec4f> &horizontal,
                                 std::vector<cv::Vec4f> &vertical,
                                 cv::Vec2f &horizontalMinMax,
                                 cv::Vec2f &verticalMinMax);
        void splitLines(const std::vector<cv::Vec4f> &lines,
                              std::vector<cv::Vec4f> &minLines,
                              std::vector<cv::Vec4f> &maxLines,
                        const LineOrientation lineOrientation,
                        const cv::Point2f &visibleCenter,
                        const float minDistanceToCenter);
        void lenghtThreshold(std::vector<cv::Vec4f> &lines, const float minCoef, cv::Vec2f &minMax, const LineOrientation lineOrientation);
        void minMaxFilter(std::vector<cv::Vec4f> &lines, const cv::Vec2f &minMax, const LineOrientation lineOrientation);
        cv::Vec4f directLine(const cv::Vec4f &line, const LineOrientation lineOrientation);
        void cropAndResizeRoi(const cv::Mat &src, cv::Mat &dst, cv::Rect &roi, const bool grayscale = true);
        void drawLines(cv::Mat &dst, const std::vector<cv::Vec4f> &lines, const cv::Scalar &color, const int thickness = 2);
        std::vector<cv::Point> prepareQuadranglePoints(const std::vector<cv::Point> &rawPoints, const cv::Mat &src, const cv::Rect &roi);
        float cosineAngleBetweenVectors(cv::Vec4i vec_ab, cv::Vec4i vec_cd);
        cv::Point2f pointIntersectionBetweenVectors(cv::Vec4f vec_ab, cv::Vec4f vec_cd);
        std::vector<cv::Point> quadranglePointsFromLines(const cv::Vec4f &top,
                                                         const cv::Vec4f &bottom,
                                                         const cv::Vec4f &left,
                                                         const cv::Vec4f &right);
        
        
        
        
        cv::Mat debugDrawRoi(const cv::Mat &src);
        cv::Mat debugDrawLines(const std::vector<cv::Vec4f> &lines, const cv::Size &size);
        cv::Mat debugDrawOrientedLines(const std::vector<cv::Vec4f> &verticalLines, const std::vector<cv::Vec4f> &horizontalLines, const cv::Size &size);
        cv::Mat debugDrawClassifiedLines(const std::vector<cv::Vec4f> &topLines,
                                         const std::vector<cv::Vec4f> &rightLines,
                                         const std::vector<cv::Vec4f> &bottomLines,
                                         const std::vector<cv::Vec4f> &leftLines,
                                         const cv::Vec2f &horizontalMinMax, const cv::Vec2f &verticalMinMax,
                                         const cv::Point2f &visibleCenter,
                                         const cv::Size &size);
        cv::Mat debugDrawBestLines(const cv::Vec4f &top, const cv::Vec4f &right, const cv::Vec4f &bottom, const cv::Vec4f &left, const cv::Size &size);
        cv::Mat debugDrawPreview(const cv::Mat &src, const std::vector<cv::Point> &quadranglePoints);
        cv::Mat debugDrawDocument(const cv::Mat &src, const std::vector<cv::Point> &quadranglePoints, const float expectAspectRatio);
        cv::Mat debugDrawAll(const std::vector<cv::Mat> matricies, const float scale = 0.85);
            
        float minFocusDistance_;
        float minVerticalLineLenght_, minHorizontalLineLenght_;
        float angleDeviationRange_;
        
        bool debugDraw_;
        
        ExpectedDocumentOrientation expectedDocumentOrientation_;
        float expectAspectRatio_;
        
        cv::Rect roi_;
        bool flip_;
        
        //
        float cumulativeARTolerance_;
        float previousTime_, PA0_processTime_;
        
        // LSD
        cv::Ptr<cv::LineSegmentDetector> lsd_, lsdPassport_, lsdGreenBook_;
        cv::LineSegmentDetectorModes lsdMode_;
        double scale_;
        double sigmaScale_;
        double quant_;
        double angleThreshold_;
        double logEps_;
        double densityThreshold_;
        int binsCount_;
    };
    
}

#endif /* document_detector_hpp */
