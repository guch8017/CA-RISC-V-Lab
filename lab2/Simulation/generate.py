import sys
print(__name__)
if __name__ == "__main__":
    fname = sys.argv[1]
    print(fname)
    if fname.endswith('inst'):
        cell_name = 'inst_cache'
    else:
        cell_name = 'ram_cell'
    with open(fname, 'r') as f:
        with open(fname + '.sv', 'w') as fo:
            lines = f.readlines()
            for i in range(len(lines)):
                #
                #if i < 678 and cell_name == 'inst_cache':
                #    fo.write(f'{cell_name}[{i}]=32\'h00000013;\n')
                #else:
                fo.write(f'{cell_name}[{i}]=32\'h{lines[i][:-1]};\n')
                    