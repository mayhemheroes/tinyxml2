// mayhem/xmltest.cpp — libFuzzer harness for tinyxml2's XML parser.
// Ported from the original mayhemheroes integration (target: xmltest). The source tree now lives
// at the repo root (/mayhem), so the include is "tinyxml2.h" (was "tinyxml2/tinyxml2.h" under the
// old OSS-Fuzz layout). One harness, one entry point: parse the fuzzed bytes as an XML document.
#include "tinyxml2.h"
#include <string>
#include <stddef.h>
#include <stdint.h>

using namespace tinyxml2;

// Entry point for LibFuzzer.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	std::string data_string(reinterpret_cast<const char*>(data), size);
	XMLDocument doc;
	doc.Parse( data_string.c_str() );

	return 0;
}
