.PHONY: build clean run install

build:
	swift build -c release
	bash Scripts/bundle.sh

clean:
	swift package clean
	rm -rf ringabell.app

install: build
	cp ringabell.app/Contents/MacOS/ringabell $(shell realpath /opt/homebrew/bin/ringabell)

run: build
	./ringabell.app/Contents/MacOS/ringabell $(ARGS)
