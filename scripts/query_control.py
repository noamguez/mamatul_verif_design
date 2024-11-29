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
    return ctr + 1
    
if __name__ == "__main__":
    ctr = control_genetate(mode_bit = 1, write_targets = 0, read_targets =0, N=2, K=2, M=2, RL_A = 0, RL_B = 0)
    print(ctr)
