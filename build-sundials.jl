#!/usr/bin/env julia
using BinDeps2

basedir = pwd()

BinDeps2.temp_prefix() do prefix
    src_path = joinpath(prefix, "src")
    build_path = joinpath(prefix, "build")
    try mkpath(src_path) end
    try mkpath(build_path) end
    
    # First, download the sources, store them into /src
    src_url = "https://computation.llnl.gov/projects/sundials/download/sundials-2.7.0.tar.gz"
    src_hash = "d39fcac7175d701398e4eb209f7e92a5b30a78358d4a0c0fcc23db23c11ba104"
    
    BinDeps2.download_verify_unpack(src_url, src_hash, src_path; verbose=true)
    
    # Build for many platforms
    for platform in BinDeps2.supported_platforms()
        cd(build_path) do
            mkdir(string(platform))
	        cd(string(platform)) do 
                target = BinDeps2.platform_map(platform)
                libsundials = BinDeps2.LibraryResult(joinpath(BinDeps2.libdir(prefix), target, "libsundials"))
                extras = platform == :win64 ? `-DCMAKE_SYSTEM_NAME=Windows` : ``
                cmake_args = `-DCMAKE_INSTALL_PREFIX=/inst/$platform -DEXAMPLES_ENABLE=OFF $extras`
                steps = [`cmake $cmake_args ../../src/sundials-2.7.0/`, 
                         `make -j4`, 
                         `make install`]
                dep = BinDeps2.Dependency("sundials", [libsundials], steps, platform, prefix)
                BinDeps2.build(dep; verbose=true, force=true)
            end
        end
    end
    # Next, package it up as a .tar.gz file
    for platform in BinDeps2.supported_platforms()
        # This could go in the loop above, but it's nice to see them all at the end.
        rm("$basedir/libsundials_$(platform).tar.gz"; force=true)
        tarball_path = BinDeps2.package(BinDeps2.Prefix("$(prefix.path)/inst/$platform"), "$basedir/libsundials", 
                                                        platform=platform, verbose=true)
        info("Built and saved at $(tarball_path)")
    end
end
 