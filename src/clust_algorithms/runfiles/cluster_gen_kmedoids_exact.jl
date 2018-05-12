CLUST_FOR_OPT=ENV["CLUST_FOR_OPT"]
push!(LOAD_PATH, normpath(joinpath(CLUST_FOR_OPT,"src"))) #adds the location of ClustForOpt to the LOAD_PATH
using ClustForOpt
using Distances
using Clustering
using JLD2
using FileIO

 ######## DATA INPUT ##########

 # region
region = "GER"


# read in original data
data_orig_daily = load_pricedata(region)
seq = data_orig_daily[:,1:365]  # do not load as sequence

println("data loaded")

# number of clusters
n_clust_min =1
n_clust_max =9

# initial points
n_kmedeoids =1 # doesn't matter for exact method


 # iterations
iterations = 1 # doesn't matter for exact methods

 ############################################

# create directory where data is saved
try
  mkdir("outfiles")
catch
 #
end

# save settings in txt file
df = DataFrame()
df[:n_clust_min]=n_clust_min
df[:n_clust_max]=n_clust_max
df[:n_kmedeoids]=n_kmedeoids
df[:iterations]=iterations
df[:region]=region

n_clust_ar = collect(n_clust_min:n_clust_max)

writetable(joinpath("outfiles",string("parameters_kmedoids_exact_",region,".txt")),df)

# normalized clustering hourly
seq_norm, hourly_mean, hourly_sdv = z_normalize(seq,scope="full")

 
problem_type_ar = ["battery", "gas_turbine"]

  centers = Dict{Tuple{Int,Int},Array}()
  clustids = Dict{Tuple{Int,Int},Array}()
  cost = zeros(length(n_clust_ar),n_kmedeoids)
  iter =  zeros(length(n_clust_ar),n_kmedeoids)
  weights = Dict{Tuple{Int,Int},Array}()
  revenue = Dict{String,Array}() 
  for i=1:length(problem_type_ar)
    revenue[problem_type_ar[i]] = zeros(length(n_clust_ar),n_kmedeoids)
  end

  
distance_type_ar = [SqEuclidean(), Cityblock()]
distance_descr = ["SqEuclidean", "Cityblock"]

for dist = 1:length(distance_type_ar)

   # initialize dictionaries of the loaded data (key: number of clusters)
  centers = Dict{Tuple{Int,Int},Array}()
  clustids = Dict{Tuple{Int,Int},Array}()
  cost = zeros(length(n_clust_ar),n_kmedeoids)
  iter =  zeros(length(n_clust_ar),n_kmedeoids)
  weights = Dict{Tuple{Int,Int},Array}()
  revenue = Dict{String,Array}() 
  for i=1:length(problem_type_ar)
    revenue[problem_type_ar[i]] = zeros(length(n_clust_ar),n_kmedeoids)
  end

   
   # iterate through settings
  for n_clust_it=1:length(n_clust_ar)
    n_clust = n_clust_ar[n_clust_it] # use for indexing Dicts
      for i = 1:n_kmedeoids
         
          results = kmedoids_exact(seq_norm,n_clust,distance_type_ar[dist])

          # save clustering results
          centers_norm = results.medoids
          centers[n_clust,i]=  undo_z_normalize(centers_norm,hourly_mean,hourly_sdv)  
          clustids[n_clust,i] = results.assignments
          cost[n_clust,i] = results.totalcost
          iter[n_clust,i] = 1
         ##########################
        
        # calculate weights
        weights[n_clust,i] = zeros(n_clust) 
        for j=1:length(clustids[n_clust,i])
            weights[n_clust,i][clustids[n_clust,i][j]] +=1
        end
        weights[n_clust,i] =  weights[n_clust,i] /length(clustids[n_clust,i])

        # run opt
        for ii=1:length(problem_type_ar)
          revenue[problem_type_ar[ii]][n_clust_it,i]=sum(run_opt(problem_type_ar[ii],(centers[n_clust,i]),weights[n_clust,i],region,false))
        end 
    
      end
  end

   # save files to jld2 file


  save_dict = Dict("centers"=>deepcopy(centers),
                   "clustids"=>deepcopy(clustids),
                   "cost"=>deepcopy(cost),
                   "iter"=>deepcopy(iter),
                   "weights"=>deepcopy(weights),
                   "revenue"=>deepcopy(revenue) )
                    
  save(string(joinpath("outfiles","aggregated_results_kmedoids_exact_"),distance_descr[dist],"_",region,".jld2"),save_dict)
  println("kmedoids exact ",distance_descr[dist] ," data revenue calculated + saved.")


end # for dist=1:length(dist_type_ar)



