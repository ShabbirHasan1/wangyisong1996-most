kern_source_files := $(wildcard kern/*.cpp)
kern_object_files := $(patsubst kern/%.cpp, \
		build/kern/%.o, $(kern_source_files))

KERN_CXX := $(CXX) -O2 $(lwip_include)

build/kern/%.o: kern/%.cpp $(header_files)
	@echo + cxx $@
	@mkdir -p $(shell dirname $@)
	@$(KERN_CXX) -c $< -o $@
