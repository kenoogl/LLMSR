module DataLoader

using CSV
using DataFrames

export load_wake_csv

function load_wake_csv(filepath::String)
    df = CSV.read(filepath, DataFrame)
    # Ensure column names are what we expect
    # Expected: x, y, z, u, v, w, k, omega, nut, deltaU, etc.
    
    # Pre-processing if needed (e.g., normalization)
    # For now, we assume data is already normalized or in correct units as per Phase 5
    
    return df
end

end # module
