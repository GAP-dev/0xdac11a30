#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import <Accelerate/Accelerate.h>
// ✅ 수정 (macOS 11+)
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define MAX_SAMPLE_SIZE 1000000
#define SHM_SIZE (4 + MAX_SAMPLE_SIZE)

unsigned char *shm_data;
bool use_shared_memory;

#if defined(__APPLE__)
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

int setup_shmem(const char *name) {
    int fd = shm_open(name, O_RDONLY, S_IRUSR | S_IWUSR);
    if (fd == -1) {
        perror("shm_open");
        return 0;
    }

    shm_data = (unsigned char *)mmap(NULL, SHM_SIZE, PROT_READ, MAP_SHARED, fd, 0);
    if (shm_data == MAP_FAILED) {
        perror("mmap");
        return 0;
    }

    close(fd);
    return 1;
}
#endif

void trigger_imageio_conversion(NSData *data) {
    @autoreleasepool {
        // 1. CGImageSource (internal decoders -> PixelConverter -> vImage)
        CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (!src) return;

        size_t count = CGImageSourceGetCount(src);
        for (size_t i = 0; i < count; i++) {
            CGImageRef image = CGImageSourceCreateImageAtIndex(src, i, NULL);
            if (!image) continue;

            // 2. Force conversion: draw into bitmap context
            size_t width = CGImageGetWidth(image);
            size_t height = CGImageGetHeight(image);
            CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 0,
                CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);

            if (ctx) {
                CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), image);
                CGContextRelease(ctx);
            }

            // 3. vImageConvert_AnyToAny trigger (manually)
            CGDataProviderRef provider = CGImageGetDataProvider(image);
            CFDataRef imgData = CGDataProviderCopyData(provider);
            if (imgData) {
                vImage_Buffer srcBuf, dstBuf;

                srcBuf.data = (void *)CFDataGetBytePtr(imgData);
                srcBuf.height = height;
                srcBuf.width = width;
                srcBuf.rowBytes = CGImageGetBytesPerRow(image);

                size_t dstSize = height * width * 4;
                void *dstData = malloc(dstSize);
                dstBuf.data = dstData;
                dstBuf.height = height;
                dstBuf.width = width;
                dstBuf.rowBytes = width * 4;

                vImage_Error err = vImageConvert_AnyToAny(NULL, &srcBuf, &dstBuf, NULL, kvImageNoFlags);
                if (err != kvImageNoError) {
                    // Optional: log error
                }

                free(dstData);
                CFRelease(imgData);
            }

            CFRelease(image);
        }

        CFRelease(src);
    }
}

void fuzz(const char *name) {
    NSData *inputData = nil;

    if (use_shared_memory) {
        uint32_t size = *(uint32_t *)(shm_data);
        if (size > MAX_SAMPLE_SIZE) size = MAX_SAMPLE_SIZE;
        inputData = [NSData dataWithBytes:(shm_data + 4) length:size];
    } else {
        inputData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:name]];
    }

    if (inputData) {
        trigger_imageio_conversion(inputData);
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <-f|-m> <file or shm name>\n", argv[0]);
        return 1;
    }

    if (!strcmp(argv[1], "-m")) {
        use_shared_memory = true;
    } else if (!strcmp(argv[1], "-f")) {
        use_shared_memory = false;
    } else {
        printf("Invalid mode: use -f (file) or -m (shared memory)\n");
        return 1;
    }

    if (use_shared_memory && !setup_shmem(argv[2])) {
        printf("Failed to setup shared memory\n");
        return 1;
    }

    fuzz(argv[2]);
    return 0;
}