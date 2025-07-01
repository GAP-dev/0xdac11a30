#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

// 파일 경로를 받아 이미지 디코딩 및 썸네일 생성까지 수행하는 fuzz 대상 함수
void fuzz(const char *path) {
    @autoreleasepool {
        NSString *filePath = [NSString stringWithUTF8String:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (!imageData) {
            return;
        }

        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)imageData);
        if (!provider) {
            return;
        }

        CGImageSourceRef imageSource = CGImageSourceCreateWithDataProvider(provider, NULL);
        if (!imageSource) {
            CGDataProviderRelease(provider);
            return;
        }

        NSDictionary *options = @{
            (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
            (id)kCGImageSourceThumbnailMaxPixelSize: @(512),
        };

        CGImageRef image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
        if (image) {
            CGImageRelease(image);
        }

        CFRelease(imageSource);
        CGDataProviderRelease(provider);
    }
}

// Entry point
int main(int argc, const char * argv[]) {
    if (argc < 2) {
        return 1;
    }

    fuzz(argv[1]);
    return 0;
}