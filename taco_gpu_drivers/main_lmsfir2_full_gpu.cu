#include <cuda_runtime.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
 #include <time.h>
#include "taco.h"
extern taco_tensor_t* init_taco_tensor(int32_t order, int32_t csize, int32_t* dimensions);
extern taco_tensor_t* init_taco_tensor_gpu(taco_tensor_t* ht);
extern void fill_array(float* arr, int len);
extern double calc_spent_time(struct timespec end, struct timespec start);
extern double average(double* values, int len);
extern void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true);
#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }

#ifndef TACO_TENSOR_T_DEFINED
#define TACO_TENSOR_T_DEFINED
typedef enum { taco_mode_dense, taco_mode_sparse } taco_mode_t;
typedef struct {
  int32_t      order;         // 
  int32_t*     dimensions;    // 
  int32_t      csize;         // 
  int32_t*     mode_ordering; // 
  taco_mode_t* mode_types;    // 
  uint8_t***   indices;       // 
  float* vals          // 
  uint8_t*     fill_value;    // 
  int32_t      vals_size;     // 
} taco_tensor_t;
#endif

// Generated by the Tensor Algebra Compiler (tensor-compiler.org)

__global__
void computeDeviceKernel0(taco_tensor_t * __restrict__ a, taco_tensor_t * __restrict__ b, taco_tensor_t * __restrict__ c, float &d_val){
  float* __restrict__ a_vals = (float*)(a->vals);
  float* __restrict__ b_vals = (float*)(b->vals);
  int c1_dimension = (int)(c->dimensions[0]);
  float* __restrict__ c_vals = (float*)(c->vals);

  int32_t i59 = blockIdx.x;
  int32_t i60 = (threadIdx.x % (256));
  if (threadIdx.x >= 256) {
    return;
  }

  int32_t i = i59 * 256 + i60;
  if (i >= c1_dimension)
    return;

  a_vals[i] = b_vals[i] + c_vals[i] * d_val;
}

int compute(taco_tensor_t *a, taco_tensor_t *b, taco_tensor_t *c, taco_tensor_t *d) {
  int c1_dimension = (int)(c->dimensions[0]);
  float* __restrict__ d_vals = (float*)(d->vals);

  float* d_val_ptr;
  gpuErrchk(cudaMallocManaged((void**)&d_val_ptr, sizeof(float)));
  float& d_val = *d_val_ptr;
  d_val = d_vals[0];

  computeDeviceKernel0<<<((c1_dimension + 255) / 256), 256>>>(a, b, c, d_val);
  cudaDeviceSynchronize();
  return 0;
}

int main(int argc, char* argv[]){
  int n_runs = atoi(argv[1]);
  if(argc < 2){
    printf("Please specify number of executions!\n");
    exit(1);
  }
  srand(time(0));
  struct timespec start, end_orig, end_taco;
  double* orig_run_times = (double*)malloc(n_runs * sizeof(double));
  double* taco_run_times = (double*)malloc(n_runs * sizeof(double));
  int NTAPS = 1000000;
  float* input = (float*)malloc(1000000 * sizeof(float));
  float* output = (float*)malloc(1000000 * sizeof(float));
  float* expected = (float*)malloc(1000000 * sizeof(float));
  float* coefficient = (float*)malloc(1000000 * sizeof(float));
  float gain = 1 + ((float)rand()) / RAND_MAX;
  float sum = 1 + ((float)rand()) / RAND_MAX;
  float error = 1 + ((float)rand()) / RAND_MAX;

  int input_dims[1] = {1000000};
  taco_tensor_t* input_tt = init_taco_tensor(1, sizeof(float), input_dims);
  input_tt->vals = input;
  input_tt = init_taco_tensor_gpu(input_tt);
  int coefficient_dims[1] = {1000000};
  taco_tensor_t* coefficient_tt = init_taco_tensor(1, sizeof(float), coefficient_dims);
  coefficient_tt->vals = output;
  coefficient_tt = init_taco_tensor_gpu(coefficient_tt);
  int error_dims[1] = {1};
  taco_tensor_t* error_tt = init_taco_tensor(1, sizeof(float), error_dims);
  error_tt->vals = &error;
  error_tt = init_taco_tensor_gpu(error_tt);

  for(int i = 0; i < n_runs; i++){
    fill_array(input, 1000000);
    fill_array(output, 1000000);
    fill_array(expected, 1000000);
    fill_array(coefficient, 1000000);

    clock_gettime(CLOCK_MONOTONIC, &start);
// lmsfir2(NTAPS, input, output, expected, coefficient, gain, sum, error);
    clock_gettime(CLOCK_MONOTONIC, &end_orig);

    compute(coefficient_tt, coefficient_tt, input_tt, error_tt);
    clock_gettime(CLOCK_MONOTONIC, &end_taco);

    orig_run_times[i] = calc_spent_time(end_orig, start);
    taco_run_times[i] = calc_spent_time(end_taco, end_orig);
  }

  double orig_time = average(orig_run_times, n_runs);
  double taco_time = average(taco_run_times, n_runs);
  printf("%.5lf %.5lf", orig_time, taco_time);
  return 0;
}
