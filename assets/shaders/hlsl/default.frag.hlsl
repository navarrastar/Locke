struct Input {
    float4 position : SV_Position;
    float4 color : TEXCOORD1;
};

float4 main(Input input) : SV_Target0 {
    return input.color;
}
