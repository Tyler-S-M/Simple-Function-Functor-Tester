#include <cuda.h>
#include <cuda_runtime.h>
#include <iostream>

#define NUM_THREADS 1024
#define FLOP_COUNT 10000

int NUM_BLOCKS = 0;
__device__ int d_NUM_BLOCKS = 0;

#define OPERATION for (int j = 0; j < FLOP_COUNT; ++j){ \
                    d_data[tid] *= 2.0f;                \
                  }                                        

/********************************

    Device Functions/Functors

********************************/

class test_runner { 

    private:
        int x = 1;

    public: 

        //for testing functor state saving
        __device__ __noinline__ void operator()(float *d_data) {
            int tid = threadIdx.x;
            if (threadIdx.x == 0){
                atomicAdd(&x, 1);
            }

            OPERATION
        }

        //for shared functor test
        __device__ __noinline__ void shared(float *d_data) {
            int tid = threadIdx.x;

            OPERATION
        }

};

//constant functor versions
__constant__ test_runner object;
__constant__ test_runner* object_ptr = &object;

//non-constant functor versions
__device__ test_runner object_dev;

//shared functor versions
__shared__ test_runner object_shared;

//functions that will either be inlined or not inlined
__device__ __noinline__ void perform_calculations(float *d_data) {
    int tid = threadIdx.x;

    OPERATION
}

__device__ void perform_calculations_inline(float *d_data) {
    int tid = threadIdx.x;

    OPERATION
}

/********************************

           Kernels

********************************/

//Kernel launches the __device__ function on each thread
__global__ void scenario1(float *d_data) {
    perform_calculations(d_data);
}

//Function for the single thread that launches a dynamic block
__global__ void scenario2(float *d_data, int depth = 0) {
    int tid = threadIdx.x;

    if (depth == 1){

        OPERATION

        return;
    }

    if (tid == 0) {

        //dynamic parallelism block with 1024 threads
        float *d_temp;
        cudaMalloc(&d_temp, NUM_THREADS * sizeof(float));
        scenario2<<<d_NUM_BLOCKS, NUM_THREADS>>>(d_temp, 1);
        cudaDeviceSynchronize();
    } 

    __syncthreads();
}

//Kernel launches the inlined __device__ function on each thread
__global__ void scenario3(float *d_data) {
    perform_calculations_inline(d_data);
}

//Kernel launches the __constant__ functor on each thread
__global__ void scenario4(float *d_data) {

    object(d_data);
}

//Kernel launches the __device__ functor on each thread
__global__ void scenario5(float *d_data) {

    object_dev(d_data);
}

//Kernel launches the __shared__ functor on each thread
//(ignoring the addition of 'x' so we use a member function
//instead of a functor call)
__global__ void scenario6(float *d_data) {

    object_shared.shared(d_data);
}

int main() {

    //vars
    float *h_data, *d_data1, *d_data2, *d_data3, *d_data4, *d_data5, *d_data6;

    cudaEvent_t start_event, stop_event;
    cudaEventCreate(&start_event);
    cudaEventCreate(&stop_event);

    float scenario1_time_ms, scenario2_time_ms, scenario3_time_ms, scenario4_time_ms, scenario5_time_ms, scenario6_time_ms;

    //Make memory for random task usage
    //(replace with what you want to test)
    h_data = new float[NUM_THREADS];
    cudaMalloc(&d_data1, NUM_THREADS * sizeof(float));
    cudaMalloc(&d_data2, NUM_THREADS * sizeof(float));
    cudaMalloc(&d_data3, NUM_THREADS * sizeof(float));
    cudaMalloc(&d_data4, NUM_THREADS * sizeof(float));
    cudaMalloc(&d_data5, NUM_THREADS * sizeof(float));
    cudaMalloc(&d_data6, NUM_THREADS * sizeof(float));

    //for each value of 'i' we run the 
    //tests and show the results.
    for (int i = 40; i <= 240; i += 40){

        NUM_BLOCKS = i;
        cudaMemcpyToSymbol(d_NUM_BLOCKS, &NUM_BLOCKS, sizeof(int), 0, cudaMemcpyHostToDevice);

        for (int j = 0; j < NUM_THREADS; j++) h_data[j] = 1.0 * j;

        cudaMemcpy(d_data1, h_data, NUM_THREADS * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_data2, h_data, NUM_THREADS * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_data3, h_data, NUM_THREADS * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_data4, h_data, NUM_THREADS * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_data5, h_data, NUM_THREADS * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_data6, h_data, NUM_THREADS * sizeof(float), cudaMemcpyHostToDevice);

        //Warm the device up to account for potential overhead
        scenario1<<<NUM_BLOCKS, NUM_THREADS>>>(d_data1);
        scenario2<<<NUM_BLOCKS, NUM_THREADS>>>(d_data2);
        scenario3<<<NUM_BLOCKS, NUM_THREADS>>>(d_data3);
        scenario4<<<NUM_BLOCKS, NUM_THREADS>>>(d_data4);
        scenario5<<<NUM_BLOCKS, NUM_THREADS>>>(d_data5);
        scenario6<<<NUM_BLOCKS, NUM_THREADS>>>(d_data6);
        cudaDeviceSynchronize();

        //Run Scenario 1
        cudaEventRecord(start_event, 0);
        scenario1<<<NUM_BLOCKS, NUM_THREADS>>>(d_data1);
        cudaEventRecord(stop_event, 0);
        cudaEventSynchronize(stop_event);

        cudaEventElapsedTime(&scenario1_time_ms, start_event, stop_event);

        //Run Scenario 2
        cudaEventRecord(start_event, 0);
        scenario2<<<NUM_BLOCKS, NUM_THREADS>>>(d_data2);
        cudaEventRecord(stop_event, 0);
        cudaEventSynchronize(stop_event);

        cudaEventElapsedTime(&scenario2_time_ms, start_event, stop_event);

        //Run Scenario 3
        cudaEventRecord(start_event, 0);
        scenario3<<<NUM_BLOCKS, NUM_THREADS>>>(d_data3);
        cudaEventRecord(stop_event, 0);
        cudaEventSynchronize(stop_event);

        cudaEventElapsedTime(&scenario3_time_ms, start_event, stop_event);

        //Run Scenario 4
        cudaEventRecord(start_event, 0);
        scenario4<<<NUM_BLOCKS, NUM_THREADS>>>(d_data4);
        cudaEventRecord(stop_event, 0);
        cudaEventSynchronize(stop_event);

        cudaEventElapsedTime(&scenario4_time_ms, start_event, stop_event);

        //Run Scenario 5
        cudaEventRecord(start_event, 0);
        scenario5<<<NUM_BLOCKS, NUM_THREADS>>>(d_data5);
        cudaEventRecord(stop_event, 0);
        cudaEventSynchronize(stop_event);

        cudaEventElapsedTime(&scenario5_time_ms, start_event, stop_event);

        //Run Scenario 6
        cudaEventRecord(start_event, 0);
        scenario6<<<NUM_BLOCKS, NUM_THREADS>>>(d_data6);
        cudaEventRecord(stop_event, 0);
        cudaEventSynchronize(stop_event);

        cudaEventElapsedTime(&scenario6_time_ms, start_event, stop_event);

        //Print times
        std::cout << "Test Results for SM Count " << i << ":\n"; 
        std::cout << "Scenario: (1024 threads, inlined kernels) time: " << scenario3_time_ms << " ms\n";
        std::cout << "Scenario: (1024 threads, individual kernels) time: " << scenario1_time_ms << " ms\n";
        std::cout << "Scenario: (1024 threads, dynamic parallelism) time: " << scenario2_time_ms << " ms\n";
        std::cout << "Scenario: (1024 threads, polymorphic functor mimic [shared]) time: " << scenario6_time_ms << " ms\n";
        std::cout << "Scenario: (1024 threads, polymorphic functor mimic [device]) time: " << scenario5_time_ms << " ms\n";
        std::cout << "Scenario: (1024 threads, polymorphic functor mimic [constant]) time: " << scenario4_time_ms << " ms\n";
        std::cout << std::endl;

    }

    return 0;
}
