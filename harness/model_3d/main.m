#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Metal/Metal.h>
#import <Vision/Vision.h> // For CoreML

#define MAX_IMAGE_SIZE (10000000) // 10MB cap

void trigger_metal_ciimage(NSData *data) {
    @autoreleasepool {
        CIImage *ciImage = [CIImage imageWithData:data];
        if (!ciImage) return;

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CIContext *metalCtx = [CIContext contextWithMTLDevice:device];

        CGImageRef cg = [metalCtx createCGImage:ciImage fromRect:[ciImage extent]];
        if (cg) {
            CFRelease(cg);
        }
    }
}

void trigger_vimage(NSData *data) {
    @autoreleasepool {
        CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (!src) return;

        CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
        if (!img) {
            CFRelease(src);
            return;
        }

        CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(img));
        if (!pixelData) {
            CGImageRelease(img);
            CFRelease(src);
            return;
        }

        size_t width = CGImageGetWidth(img);
        size_t height = CGImageGetHeight(img);
        size_t rowBytes = CGImageGetBytesPerRow(img);

        vImage_Buffer srcBuf, dstBuf;
        srcBuf.data = (void *)CFDataGetBytePtr(pixelData);
        srcBuf.height = height;
        srcBuf.width = width;
        srcBuf.rowBytes = rowBytes;

        void *dstData = malloc(height * width * 4);
        dstBuf.data = dstData;
        dstBuf.height = height;
        dstBuf.width = width;
        dstBuf.rowBytes = width * 4;

        vImageConvert_AnyToAny(NULL, &srcBuf, &dstBuf, NULL, kvImageNoFlags);

        free(dstData);
        CFRelease(pixelData);
        CGImageRelease(img);
        CFRelease(src);
    }
}

void trigger_coreml(NSData *data) {
    @autoreleasepool {
        NSString *modelPath = @"MyModel.mlmodelc"; // Replace with actual path
        NSURL *url = [NSURL fileURLWithPath:modelPath];
        MLModel *mlmodel = [MLModel modelWithContentsOfURL:url error:nil];
        if (!mlmodel) return;

        VNCoreMLModel *vnModel = [VNCoreMLModel modelForMLModel:mlmodel error:nil];
        if (!vnModel) return;

        VNCoreMLRequest *req = [[VNCoreMLRequest alloc] initWithModel:vnModel];
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithData:data options:@{}];
        [handler performRequests:@[req] error:nil];
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            printf("Usage: %s <image file>\n", argv[0]);
            return 1;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSData *data = [NSData dataWithContentsOfFile:path];

        if (!data || data.length > MAX_IMAGE_SIZE) {
            printf("Invalid or too large input\n");
            return 1;
        }

        trigger_metal_ciimage(data);
        trigger_vimage(data);
        // trigger_coreml(data); // Uncomment if you have a model

        printf("Fuzz pass complete\n");
    }
    return 0;
}