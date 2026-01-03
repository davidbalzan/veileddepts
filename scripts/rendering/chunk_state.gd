## ChunkState enum for terrain chunk lifecycle management
##
## Defines the possible states a terrain chunk can be in during its lifecycle.
## Used by the streaming system to track chunk loading/unloading progress.

class_name ChunkState

enum State { UNLOADED, LOADING, LOADED, UNLOADING }  ## Not in memory  ## Being loaded asynchronously  ## Fully loaded and rendered  ## Being unloaded
