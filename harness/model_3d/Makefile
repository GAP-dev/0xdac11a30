APP_NAME = imageio_harness
SRC = main.m

FRAMEWORKS = -framework Foundation \
             -framework AppKit \
             -framework CoreGraphics \
             -framework ImageIO \
             -framework Accelerate \
             -framework CoreImage \
             -framework Metal \
             -framework Vision \
             -framework UniformTypeIdentifiers \
             -framework CoreML

$(APP_NAME): $(SRC)
	clang -fobjc-arc $(SRC) -o $(APP_NAME) $(FRAMEWORKS)

clean:
	rm -f $(APP_NAME)