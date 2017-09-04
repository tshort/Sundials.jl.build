#!/usr/bin/env julia
using BinDeps2
using SHA

basedir = pwd()

# Our build products will go into ./products
out_path = joinpath(pwd(), "products")
rm(out_path; force=true, recursive=true)
mkpath(out_path)

products = Dict()

temp_prefix() do prefix
    src_path = joinpath(prefix, "src")
    build_path = joinpath(prefix, "build")
    try mkpath(src_path) end
    try mkpath(build_path) end
    
    # First, download the sources, store them into /src
    src_url = "https://computation.llnl.gov/projects/sundials/download/sundials-2.7.0.tar.gz"
    src_hash = "d39fcac7175d701398e4eb209f7e92a5b30a78358d4a0c0fcc23db23c11ba104"
    
    download_verify_unpack(src_url, src_hash, src_path; verbose=true)

    # Build for many platforms
    for platform in supported_platforms()
        cd(build_path) do
            mkdir(string(platform))
	    cd(string(platform)) do 
                target = platform_triplet(platform)
                libsundials = LibraryResult(joinpath(libdir(prefix), target, "libsundials"))
                extras = platform in (:win64,:win32) ? `-DCMAKE_SYSTEM_NAME=Windows` : ``
                cmake_args = `-DCMAKE_INSTALL_PREFIX=/inst/$platform -DEXAMPLES_ENABLE=OFF $extras`
                steps = [`cmake $cmake_args ../../src/sundials-2.7.0/`, 
                         `make -j4`, 
                         `make install`]
                dep = Dependency("sundials", [libsundials], steps, platform, prefix)
                build(dep; verbose=true, force=true)
                rm("$basedir/libsundials_$(target).tar.gz"; force=true)
                tarball_path = package(BinDeps2.Prefix("$(prefix.path)/inst/$platform"), 
			               "$basedir/products/libsundials", 
                                       platform=platform, verbose=true)
                # Once we're built up, go ahead and package this prefix out
                tarball_hash = open(tarball_path, "r") do f
                    return bytes2hex(sha256(f))
                end
                products[target] = (basename(tarball_path), tarball_hash)
                info("Built and saved at $(tarball_path)")
            end
        end
    end
end

# In the end, dump an informative message telling the user how to download/install these
info("Hash/filename pairings:")
for target in keys(products)
    filename, hash = products[target]
    println("    \"$(target)\" => (\"\$prefix/$(filename)\", \"$(hash)\"),")
end 
