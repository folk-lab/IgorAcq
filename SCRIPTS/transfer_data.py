import os, glob, re, sys
import paramiko

def get_key_encrypt(pkey):
    ''' determine what type of encryption key this is '''
    basename = os.path.basename(pkey)
    match = re.search('id_([a-zA-Z0-9]+)', basename)
    if match:
        return match.group(1)
    else:
        raise IOError('Key encryption type not \
                    recognized: {0:s}'.format(basename))

def read_private_key(pkey):
    encrypt = get_key_encrypt(pkey)
    if(encrypt == 'ed25519'):
        return paramiko.Ed25519Key(filename=pkey)
    elif(encrypt == 'rsa'):
        return paramiko.RSAKey(filename=pkey)
    else:
        raise IOError('Cannot handle key with \
                       encryption type: {0:s}'.format(encrypt))

def yield_private_keys():
    ''' look for private keys in ~/.ssh/id_* '''

    private_key_search = os.path.join(os.path.expanduser('~'),
                                  '.ssh\id_*')
    key_list = glob.glob(private_key_search) # get all keys
    if(len(key_list)==0):
        raise IOError('Public key not found!')
    public_keys = [k for k in key_list if k.endswith('.pub')]
    private_keys = [k for k in key_list if not k.endswith('.pub')]
    for pkey in private_keys:
        yield(pkey)

def connect_sftp(username, server, port):
    ''' open sftp connection to server '''
    for key_loc in yield_private_keys():
        try:
            pkey = read_private_key(key_loc)
            transport = paramiko.Transport((server,port))
            transport.use_compression()
            transport.connect(username=username, pkey=pkey)

            return paramiko.SFTPClient.from_transport(transport)

        except Exception as e:
            print('Exception while opening SFTP: {0:s}'.format(e))

    # if you made it this far, connecting has definitely failed
    raise IOError('Could not open SFTP session with host: {0:s}'.format(server))

def mkdir_p(sftp, remote_directory):
    """Change to this directory, recursively making new folders if needed.
    Returns True if any folders were created."""
    # stolen from: https://stackoverflow.com/questions/14819681

    if remote_directory == '/':
        # absolute path so change directory to root
        sftp.chdir('/')
        return
    if remote_directory == '':
        # top-level relative directory must exist
        return
    try:
        sftp.chdir(remote_directory) # sub-directory exists
    except IOError:
        dirname, basename = os.path.split(remote_directory.rstrip('/'))
        mkdir_p(sftp, dirname) # make parent directories
        sftp.mkdir(basename) # sub-directory missing, so created it
        sftp.chdir(basename)
        return True

def put(sftp, local_file, remote_file):
    ''' check directory, then move file '''
    # cleanup paths
    local_file = os.path.join(local_file.strip())
    remote_file = os.path.join(remote_file.strip())

    # check that directories exist
    rem_dir, rem_base = os.path.split(remote_file)
    mkdir_p(sftp,rem_dir)

    # put
    sftp.put(local_file, remote_file)

if __name__ == '__main__':
    # transfer all the files listed in pending_sftp.lst

    with open(os.path.join(sys.argv[1])) as f:
        lines = f.readlines()

    # try to open connection to sftp server
    username, server, port = [s.strip() for s in lines[0].split(',')]
    port = int(port)
    sftp = connect_sftp(username, server, port)

    # send files
    try:
        filenames = [l.split(',') for l in lines[1:]]
        for loc, rem in filenames:
            put(sftp, loc, rem)
            print "Uploaded: {0:s}".format(loc)
    except Exception as e:
        print('Exception caught during sftp.put: '.format(e))

    sftp.close()
