// mayhem/xmltest2.cpp — libFuzzer harness for tinyxml2's XML file loader (target: xmltest2).
// Ported from OSS-Fuzz's projects/tinyxml2/xmltest2.cpp. Unlike xmltest (which parses an in-memory
// string via XMLDocument::Parse), this harness exercises the LoadFile path: it writes the fuzzed
// bytes to a temp file and loads them with XMLDocument::LoadFile. The source tree now lives at the
// repo root (/mayhem), so the include is "tinyxml2.h" (OSS-Fuzz used "tinyxml2/tinyxml2.h").
#include "tinyxml2.h"

#include <string>
#include <cstdio>
#include <cstdint>
#include <cstdlib>

#include <unistd.h>

using namespace tinyxml2;
using namespace std;

// Entry point for LibFuzzer.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	char pathname[256];
	sprintf(pathname, "/tmp/libfuzzer.%d", getpid());
	FILE *fp = fopen(pathname, "wb");
	fwrite(data, size, 1, fp);
  	fclose(fp);

	XMLDocument doc;
	doc.LoadFile(pathname);

    unlink(pathname);
	return 0;
}
