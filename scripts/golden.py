import numpy as np
import sys
import random as rnd

DATA_WIDTH = 32
BUS_WIDTH = 64
SP_SIZE =4
MAX_DIM = BUS_WIDTH // DATA_WIDTH

def read_matrixes(sp):
    txt = open("data_file.txt", "r").read()
    test_index = 0
    results = []
    iterations = txt.rsplit("#control\n")
    for test in iterations[1:]:
        control_reg = int(test[:test.find('\n')]) #get control reg
        mode, write_target, read_target, data_flow_type, n, k, m, RL_A, RL_B = read_control(control_reg)
        A_index = test.rindex("A")
        B_index = test.rindex("B")
        END_index = test.rindex("END")
        print("############# CONTROL of test: " + str(test_index) +"  ###########\n")
        print(control_reg)
        print("control params: ")
        print("mode: " + str(mode) + '\n')
        print("write_target: " + str(write_target) + '\n')
        print("read_target: " + str(read_target) + '\n')
        print("n: "+ str(n)+ '\n')
        print("k: "+ str(k)+ '\n')
        print("m: "+ str(m)+ '\n')
        print("RL_A: "+ str(RL_A)+ '\n')
        print("RL_B: "+ str(RL_B)+ '\n')
        print("control params: ")
        if(A_index != -1):
            matA_flat = test[A_index + 2: B_index -1].rsplit('\n')
            matrix_A = np.array([line.rsplit(' ') for line in matA_flat], dtype=np.int64)
            
        if(B_index != -1):
            matB_flat = test[B_index + 2: END_index -1].rsplit('\n')
            matrix_B = np.array([line.rsplit(' ') for line in matB_flat], dtype=np.int64)
        
        print("matrix A: \n")
        print(matrix_A)
        print("matrix B: \n")
        print(matrix_B)
        res_mat = np.dot(matrix_A, matrix_B)
        print("res BEFORE bias\n")
        print(res_mat)
        if(mode == 1):   #if in bias mode
            matrix_C = get_bias_mat(sp, read_target, n,m) #get matrix c from sp
            res_mat += matrix_C
            print("matrix C: \n")
            print(matrix_C)
            print("res AFTER bias\n")
            print(res_mat)
        update_sp(sp, res_mat, write_target,n,m)
        results.append((res_mat,control_reg))
        if(test_index <=7 and test_index >= 2):
            print(sp)
        test_index+=1
    return results

def update_sp(sp, res_mat, write_target,n,m):
    sp[write_target][0:n, 0:m] = res_mat

def get_bias_mat(sp, read_target, n,m):
    return sp[read_target][:n, :m]

def read_control(ctr):
    return  ((ctr&2) >>1, (ctr&(4+8))>>2,(ctr&(16 +32))>>4, ctr&(64+128)>>6, (ctr>>8)%4+1, (ctr>>10)%4+1, (ctr>>12)%4+1, (ctr&16384)>>14, (ctr&32768)>>15)
    


def write_results(results):
    with open('golden.txt', 'w') as write_f:
        for res_tup in results:
            write_f.write("#control\n")
            write_f.write(str(res_tup[1])+"\n") # write control 
            np.savetxt(write_f, res_tup[0], fmt='%d', delimiter=' ') #write_resmat
            write_f.write("END\n")


def control_genetate(mode_bit = 0, write_targets = 0, read_targets =0, N=2, K=2,M=2, RL_A = 0, RL_B = 0):
    data_flow_type = 1
    ctr = 0
    ctr |= (2 *mode_bit)          
    ctr |= (4 *write_targets)
    ctr |= (16 *read_targets)
    ctr |= (64 *data_flow_type)
    ctr |= (256 *(N-1))
    ctr |= (1024 *(K-1))
    ctr |= (4096 *(M-1))
    ctr |= (16384 *RL_A)
    ctr |= (32768 *RL_B)
    return ctr+1
       
def random_generate(mats_amount ):
    limit_value = 2**(DATA_WIDTH-1) -1
    optional_dims = [i for i in range(2,MAX_DIM+1)]
    optional_targets = [0]
    if (SP_SIZE == 2):
        optional_targets.append(1)
    elif(SP_SIZE == 4):
        optional_targets+=[1,2,3]
    with open('data_file.txt', 'w') as write_f:
        for i in range(mats_amount):
            
            if i >0:
                print(i)
                RL_A_PREV = RL_A_rand
                RL_B_PREV = RL_B_rand
                A_prev = Amatrix
                B_prev = Bmatrix
                prev_n = n
                prev_k = k
                prev_m = m
            
            n = rnd.choice(optional_dims)
            k = rnd.choice(optional_dims)
            m = rnd.choice(optional_dims)
            mode_rand = rnd.choice([0,min(1,i)])
            RL_A_rand = rnd.choice([0,min(1,i)])
            RL_B_rand = rnd.choice([0,min(1,i)])
            read_targ_rand = rnd.choice(optional_targets)
            write_targ_rand = rnd.choice(optional_targets)
            
                   
            Amatrix = np.random.randint( (-1) * limit_value, limit_value, size=(n, k))
            Bmatrix = np.random.randint( (-1) * limit_value, limit_value, size=(k, m))
            if i> 0:
                if RL_A_PREV == 1:
                    print("RELOAD A!")
                    Amatrix = A_prev
                    n = prev_n
                    k = prev_k
                    Bmatrix = np.random.randint( (-1) * limit_value, limit_value, size=(k, m))
                if RL_B_PREV == 1:
                    print("RELOAD B!")
                    Bmatrix = B_prev
                    k = prev_k
                    m = prev_m
                    if RL_A_PREV == 0:
                        Amatrix = np.random.randint( (-1) * limit_value, limit_value, size=(n, k))
            ctr = control_genetate(mode_bit = mode_rand, write_targets = write_targ_rand, read_targets =read_targ_rand, N=n, K=k, M=m, RL_A = RL_A_rand, RL_B = RL_B_rand)
            write_f.write("#control\n")
            write_f.write(str(ctr)+"\n") #write control 
            write_f.write("A\n")          #write matA
            np.savetxt(write_f, Amatrix, fmt='%d', delimiter=' ')
            write_f.write("B\n")          #write matB
            np.savetxt(write_f, Bmatrix, fmt='%d', delimiter=' ')
            write_f.write("END\n")
        
    
    #print(Amatrix)
 
if __name__ == "__main__":
    sp = [np.zeros((MAX_DIM,MAX_DIM), dtype=np.int64)   for i in range(SP_SIZE)] #create scartchpad
    want_random_generate = sys.argv[1]
    if(want_random_generate =='1'):
        mats_amount = int(sys.argv[2])
        random_generate(mats_amount)
    results = read_matrixes(sp)
    write_results(results)
    print("------END OF SCRIPT-------")
    print(sp)
    #print(mats)
    #print(results)
    
