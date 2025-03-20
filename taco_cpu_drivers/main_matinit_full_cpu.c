
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
 #include <time.h>
#include "taco.h"
extern taco_tensor_t* init_taco_tensor(int32_t order, int32_t csize, int32_t* dimensions);

extern void fill_array(float* arr, int len);
extern double calc_spent_time(struct timespec end, struct timespec start);
extern double average(double* values, int len);



#ifndef TACO_TENSOR_T_DEFINED
#define TACO_TENSOR_T_DEFINED
typedef enum { taco_mode_dense, taco_mode_sparse } taco_mode_t;
typedef struct {
  int32_t      order;          
  int32_t*     dimensions;     
  int32_t      csize;          
  int32_t*     mode_ordering;  
  taco_mode_t* mode_types;     
  uint8_t***   indices;        
  uint8_t*     vals;           
  uint8_t*     fill_value;     
  int32_t      vals_size;      
} taco_tensor_t;
#endif

// Generated by the Tensor Algebra Compiler (tensor-compiler.org)

int compute(taco_tensor_t *a, taco_tensor_t *b) {
  int a1_dimension = (int)(a->dimensions[0]);
  int a2_dimension = (int)(a->dimensions[1]);
  float* restrict a_vals = (float*)(a->vals);
  float* restrict b_vals = (float*)(b->vals);

  float b_val = b_vals[0];

  #pragma omp parallel for schedule(runtime)
  for (int32_t i = 0; i < a1_dimension; i++) {
    for (int32_t j = 0; j < a2_dimension; j++) {
      int32_t ja = i * a2_dimension + j;
      a_vals[ja] = b_val;
    }
  }
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
  float* mat = (float*)malloc(1000 * 1000 * sizeof(float));
  float val = 1 + ((float)rand()) / RAND_MAX;
  int m = 1000;
  int n = 1000;

  int mat_dims[2] = {1000,1000};
  taco_tensor_t* mat_tt = init_taco_tensor(2, sizeof(float), mat_dims);
  mat_tt->vals = mat;

  int val_dims[1] = {1};
  taco_tensor_t* val_tt = init_taco_tensor(1, sizeof(float), val_dims);
  val_tt->vals = &val;


  for(int i = 0; i < n_runs; i++){
    fill_array(mat, 1000 * 1000);

    clock_gettime(CLOCK_MONOTONIC, &start);
 matinit(mat, val, m, n);
    clock_gettime(CLOCK_MONOTONIC, &end_orig);

    compute(mat_tt, val_tt);
    clock_gettime(CLOCK_MONOTONIC, &end_taco);

    orig_run_times[i] = calc_spent_time(end_orig, start);
    taco_run_times[i] = calc_spent_time(end_taco, end_orig);
  }

  double orig_time = average(orig_run_times, n_runs);
  double taco_time = average(taco_run_times, n_runs);
  printf("%.5lf %.5lf", orig_time, taco_time);
  return 0;
}
