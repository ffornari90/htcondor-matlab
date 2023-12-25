function configCluster
% Configure MATLAB to submit to the cluster.

% Copyright 2013-2023 The MathWorks, Inc.

% Cluster list
cluster_dir = fullfile(fileparts(mfilename('fullpath')),'IntegrationScripts');
% Listing of setting file(s).  Derive the specific one to use.
cluster_list = dir(cluster_dir);
% Ignore . and .. directories
cluster_list = cluster_list(arrayfun(@(x) x.name(1), cluster_list) ~= '.');
len = length(cluster_list);
if len==0
    error('No cluster directory exists.')
elseif len==1
    cluster = cluster_list.name;
else
    cluster = lExtractPfile(cluster_list);cloud
end

% Import cluster definitions
def = clusterDefinition(cluster);

% Determine the name of the cluster profile
if isfield(def,'Name')
    profile = def.Name;
else
    profile = cluster;
end

% Delete the profile (if it exists)
% In order to delete the profile, check first if an existing profile.  If
% so, check if it's the default profile.  If so, set the default profile to
% "local" (otherwise, MATLAB will throw the following warning)
%
%  Warning: The value of DefaultProfile is 'name-of-profile-we-want-to-delete'
%           which is not the name of an existing profile.  Setting the
%           DefaultProfile to 'local' at the user level.  Valid profile
%           names are:
%           'local' 'profile1' 'profile2' ...
%
% This way, we bypass the warning message.  Then remove the old incarnation
% of the profile (that we're going to eventually create.)
if verLessThan('matlab','9.13')
    % R2022a and older
    % Handle to function returning list of cluster profiles
    cp_fh = @parallel.clusterProfiles;
    % Handle to function returning default cluster profile
    dp_fh = @parallel.defaultClusterProfile;
else
    % R2022b and newer
    % Handle to function returning list of cluster profiles
    cp_fh = @parallel.listProfiles;
    % Handle to function returning default cluster profile
    dp_fh = @parallel.defaultProfile;
end
if any(strcmp(profile,feval(cp_fh))) %#ok<*FVAL>
    % The profile exists.  Check if it's the default profile.
    if strcmp(profile,feval(dp_fh))
        % The profile is the default profile.  Change the default profile
        % to the default profile (local or Processes) to avoid the
        % afformentioned warning.

        % Get the list of factory profile names
        %
        %  Before R2022b: local
        %  After  R2022a: Processes, Threads
        %
        % In either case, pick the first one
        fpn = parallel.internal.settings.getFactoryProfileNames;
        dp_fh(fpn{1});
    end
    % The profile is not the default profile, safely remove it.
    parallel.internal.ui.MatlabProfileManager.removeProfile(profile)
end

% Checks to see if ClusterHost is set to determine job submission type.
if isfield(def, 'AdditionalProperties') && ...
        isfield(def.AdditionalProperties, 'ClusterHost') && ...
        strlength(def.AdditionalProperties.ClusterHost)>0
    CLUSTER_HOST_SET = true;
else
    CLUSTER_HOST_SET = false;
end

% Checks to see if HasSharedFileSystem is set to true or false
if isfield(def, 'HasSharedFilesystem') && ...
        ~isempty(def.HasSharedFilesystem) && def.HasSharedFilesystem
    HAS_SHARED_FILESYSTEM = true;
else
    HAS_SHARED_FILESYSTEM = false;
end

% Construct the user's Job Storage Location folder
if CLUSTER_HOST_SET && HAS_SHARED_FILESYSTEM
    user = lGetRemoteUsername(cluster);
    if ispc
        if ~isfield(def, 'JobStorageLocation') || ~isfield(def.JobStorageLocation, 'Windows') || ...
                strlength(def.JobStorageLocation.Windows)==0
            error(['JobStorageLocation.Windows field must exist and not be empty in the configuration file.' ...
                10 'Specify the UNC Path that the MATLAB client has access to on the cluster.'])
        elseif ~isfield(def, 'JobStorageLocation') || ~isfield(def.JobStorageLocation, 'Unix') || ...
                strlength(def.JobStorageLocation.Unix)==0
            error(['JobStorageLocation.Unix field must exist and not be empty in the configuration file.' ...
                10 'Specify the path that the MATLAB client has access to on the cluster.'])
        else
            jsl = def.JobStorageLocation.Windows;
            rjsl = def.JobStorageLocation.Unix;
        end
    else
        if ~isfield(def, 'JobStorageLocation') || ~isfield(def.JobStorageLocation, 'Unix') || ...
                strlength(def.JobStorageLocation.Unix)==0
            error(['JobStorageLocation.Unix field must exist and not be empty in the configuration file.' ...
                10 'Specify the path that the MATLAB client has access to on the cluster.'])
        else
            jsl = def.JobStorageLocation.Unix;
            rjsl = '';
        end
    end
    % Modify the JobStorageLocation with the user-specified username
    if ~isempty(jsl)
        % Gather the username environment variable
        if ispc
            envusr = getenv('USERNAME');
        else
            envusr = getenv('USERNAME');
        end
        % Replace the username environment variable with the user-specified value
        if contains(jsl,envusr)
            jsl = replace(jsl, envusr, user);
        end
    end
elseif CLUSTER_HOST_SET
    user = lGetRemoteUsername(cluster);
    rjsl = def.AdditionalProperties.RemoteJobStorageLocation;
    jsl = def.JobStorageLocation;
else
    jsl = '/home/matlabuser';
    envusr = getenv('USERNAME');
    rjsl = fullfile('/s3/', envusr);
    user = 'matlabuser';
    def.ClusterHost = 'localhost';
    ScheddNode = input(['HTCondor Schedd node FQDN (e.g. <IP_ADDRESS>.myip.cloud.infn.it): '],'s');

    homeDirectory = getenv('HOME');
    condorDirectory = fullfile(homeDirectory, '.condor');
    userConfigPath = fullfile(condorDirectory, 'user_config');

    if ~isfolder(condorDirectory)
        mkdir(condorDirectory);
    end

    fileID = fopen(userConfigPath, 'w');
    fprintf(fileID, 'CONDOR_HOST = %s\n', ScheddNode);
    fclose(fileID);

    if isempty(ScheddNode)
        error(['Failed to configure cluster: ' cluster])
    end

    submitCommand = ['/usr/local/bin/condor_submit -spool /home/matlabuser/oidc_agent_job.sub'];

    status = system(submitCommand);

    if status == 0
        disp('Jupyter environment successfully transferred to WN.');
    else
        disp('Transfer of Jupyter environment to WN failed.');
    end

    sshkey = '/home/matlabuser/.ssh/id_rsa';
    if exist(sshkey, 'file') == 2
        def.IdentityFile = sshkey;
        def.UseIdentityFile = true;
        def.AuthenticationMode = 'IdentityFile';
    else
        error(['File not found: ' sshkey]);
    end
    def.ClusterMatlabRoot = '/opt/matlab/R2023a';
    def.HasSharedFilesystem = false;
    [status, output] = system('/usr/local/bin/condor_status -json | /usr/bin/jq ". | length"');
    if status == 0
        cleanedOutput = regexprep(output, '\x1B\[[0-9;]*[a-zA-Z]', '');
        fprintf('Number of HTCondor WN is: %s\n', cleanedOutput);
        if ~isempty(cleanedOutput)
            numWorkers = str2double(cleanedOutput);
            if isnumeric(numWorkers) && isscalar(numWorkers) && mod(numWorkers, 1) == 0
                def.NumWorkers = int32(numWorkers);
            else
                fprintf('Error: Output is not a valid integer.\n');
            end
        else
            fprintf('Error: No numeric value found in the output.\n');
        end
    else
        fprintf('Error executing the command: %s\n', output);
    end
    CLUSTER_HOST_SET = true;
end

% Create the Job Storage Location if it doesn't already exist
if exist(jsl,'dir')==false
    [status, err, eid] = mkdir(jsl);
    if status==false
        error(eid,'Failed to create directory %s: %s', jsl, err)
    end
end

% Modify the rjsl with the user-specified username
%if ~isempty(rjsl)
    % Gather the username environment variable
    %if ispc
    %    envusr = getenv('USERNAME');
    %else
     %   envusr = getenv('USERNAME');
    %end
    % Replace the username environment variable with the user-specified
    % value.
    %if contains(rjsl,envusr)
     %   rjsl = replace(rjsl, envusr, user);
    %end
%end

% Assemble the cluster profile with the information collectedy
assembleClusterProfile(jsl, rjsl, cluster, user, profile, def, CLUSTER_HOST_SET, HAS_SHARED_FILESYSTEM);

lNotifyUserOfCluster(profile)

% % Validate if you want to
% ps.Profiles(pnidx).validate

end


function cluster_name = lExtractPfile(cl)
% Display profile listing to user to select from

len = length(cl);
for pidx = 1:len
    name = cl(pidx).name;
    names{pidx,1} = name; %#ok<AGROW>
end

selected = false;
while selected==false
    for pidx = 1:len
        fprintf('\t[%d] %s\n',pidx,names{pidx});
    end
    idx = input(sprintf('Select a cluster [1-%d]: ',len));
    selected = idx>=1 && idx<=len;
end
cluster_name = cl(idx).name;

end


function un = lGetRemoteUsername(~)

un = getenv('USERNAME');

end


function assembleClusterProfile(jsl, rjsl, cluster, user, profile, def, CLUSTER_HOST_SET, HAS_SHARED_FILESYSTEM)

% Create generic cluster profile
c = parallel.cluster.Generic;

% Required mutual fields
% Location of the Integration Scripts
c.IntegrationScriptsLocation = fullfile(fileparts(mfilename('fullpath')),'IntegrationScripts', cluster);
c.NumWorkers = def.NumWorkers;
c.OperatingSystem = 'unix';

% Import list of AdditionalProperties from the config file
% CAUTION: Will overwrite any duplicate fields already set in this file
if isfield(def, 'AdditionalProperties')
    configProps = fieldnames(def.AdditionalProperties);
    for i = 1:length(configProps)
        c.AdditionalProperties.(configProps{i}) = def.AdditionalProperties.(configProps{i});
    end
end

c.HasSharedFilesystem = def.HasSharedFilesystem;

if CLUSTER_HOST_SET
    c.AdditionalProperties.Username = user;
    c.AdditionalProperties.ClusterHost = def.ClusterHost;
    c.AdditionalProperties.AuthenticationMode = def.AuthenticationMode;
    c.AdditionalProperties.UseIdentityFile = def.UseIdentityFile;
    c.AdditionalProperties.IdentityFile = def.IdentityFile;
    c.AdditionalProperties.RemoteJobStorageLocation = rjsl;
    if isfield(def, 'ClusterMatlabRoot') && ~isempty(def.ClusterMatlabRoot)
        c.ClusterMatlabRoot = def.ClusterMatlabRoot;
    end
    if HAS_SHARED_FILESYSTEM
        if ispc
            jsl = struct('windows',jsl,'unix',rjsl);
            if isprop(c.AdditionalProperties, 'RemoteJobStorageLocation')
                c.AdditionalProperties.RemoteJobStorageLocation = '';
            end
        end
    else
        c.AdditionalProperties.RemoteJobStorageLocation = rjsl;
    end
end
c.JobStorageLocation = jsl;

% Save Profile
c.saveAsProfile(profile);
c.saveProfile('Description', profile)

% Set as default profile
parallel.defaultClusterProfile(profile);

end


function lNotifyUserOfCluster(profile)

%{
cluster = split(profile);
cluster = cluster{1};
fprintf(['\n\tMust set QueueName before submitting jobs to %s.  E.g.\n\n', ...
         '\t>> c = parcluster;\n', ...
         '\t>> c.AdditionalProperties.QueueName = ''queue-name'';\n', ...
         '\t>> c.saveProfile\n\n'], upper(cluster))
%}

% configCluster completed
fprintf('Complete.  Default cluster profile set to "%s".\n', profile)
w = warning ('off','all');

end
