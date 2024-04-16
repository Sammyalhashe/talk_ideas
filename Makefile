.phony: threadPerfTest
threadPerfTest:
	zig build-exe code/threadPerfTest.zig -lc -lplot && ./threadPerfTest && rm ./threadPerfTest

.phony: clean_threadPerfTest
clean_threadPerfTest:
	rm threadPerfTest.* \
		&& rm *.png

