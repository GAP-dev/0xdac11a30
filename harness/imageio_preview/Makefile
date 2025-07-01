# Makefile for image_crash_harness

APP_NAME = harness
SRC = main.m
FRAMEWORKS = -framework Foundation -framework AppKit

$(APP_NAME): $(SRC)
	clang $(SRC) -o $(APP_NAME) $(FRAMEWORKS)

clean:
	rm -f $(APP_NAME)