layout(set = 0, binding = 0, std430) restrict buffer Params{
    float num_monsters;
    float image_size;
    float scale;
    float collision_radius;
    float collision_factor;
    float max_vel;
    float player_pos_x;
    float player_pos_y;
    float game_time;
    float delta_time;
    float pause;
    float color_mode;
    float weapon_pos_x;
    float weapon_pos_y;
    float weapon_dir_x;
    float weapon_dir_y;
} params;

layout(set = 0, binding = 1, std430) restrict buffer BinParams{
    int bin_size;
    int bins_x;
    int bins_y;
    int num_bins;
} bin_params;

layout(set = 0, binding = 2, std430) restrict buffer Bin{
    int data[];
} bin;

layout(set = 0, binding = 3, std430) restrict buffer BinCount{
    int data[];
} bin_sum;

layout(set = 0, binding = 4, std430) restrict buffer ReindexBinCount{
    int data[];
} bin_prefix_sum;

layout(set = 0, binding = 5, std430) restrict buffer ReindexBin{
    int data[];
} bin_index_tracker;

layout(set = 0, binding = 6, std430) restrict buffer ReindexBinPositions{
    int data[];
} bin_reindex;

layout(rgba32f, binding = 7) uniform image2D monster_data;

layout(rgba32f, binding = 8) uniform image2D bullet_data;

ivec2 one_to_two(int index, int grid_width){
    int row = int(index / grid_width);
    int col = int(mod(index, grid_width));
    return ivec2(col,row);
}

int two_to_one(vec2 index, int grid_width){
    int row = int(index.y);
    int col = int(index.x);
    return row * grid_width + col;
}