.PHONY: build clean run

build:
	swift build -c release
	bash Scripts/bundle.sh

clean:
	swift package clean
	rm -rf ringabell.app

run: build
	./ringabell.app/Contents/MacOS/ringabell $(ARGS)
