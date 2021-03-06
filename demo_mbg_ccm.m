% This code is to reproduce the experiments reported in paper
% "Using covariance matrix with superpixel for unsupervised colour image segmentation"


clc;
clear; close all;

addpath 'msseg'
addpath 'Graph_based_segment'
addpath 'makeBipartiteGraph'
addpath 'utilities'
addpath 'evals'
addpath 'others'



%%% set parameters for bipartite graph
para.alpha = 0.001; % affinity between pixels and superpixels
para.beta  =  20;   % scale factor in superpixel affinity
para.gamma = 0.5;
% para.theta = 20;   % scale factor in texture-based superpixel affinity
% para.gamma1  = -1; %scale factor in texture based superpixel affinity 
% para.gamma2  = -1; %scale factor in color based superpixel affinity
para.nb = 1; % number of neighbors for superpixels (i.e.k-NN of superpixel)
para.distType = 'LogEuclidean';


% read numbers of segments used in the paper 
bsdsRoot = '..\..\BSR\BSDS500\data';
fid = fopen(fullfile(bsdsRoot,'Nsegs300.txt'),'r');
Nimgs = 300;
[BSDS_INFO] = fscanf(fid,'%d %d\n',[2,Nimgs]);
fclose(fid);

PRI_all = zeros(Nimgs,1);
VoI_all = zeros(Nimgs,1);
GCE_all = zeros(Nimgs,1);
BDE_all = zeros(Nimgs,1);

warning( 'off', 'all');
for idxI = 1:Nimgs
    
    % read number of segments
    %Nseg = BSDS_INFO(2,idxI);
    % or, set Nseg=2;
    Nseg = 2;% BSDS_INFO(2,idxI);
    
    % locate image
    img_name = int2str(BSDS_INFO(1,idxI));
    img_loc = fullfile(bsdsRoot,'images','test',[img_name,'.jpg']);    
    if ~exist(img_loc,'file')
        img_loc = fullfile(bsdsRoot,'images','train',[img_name,'.jpg']);
        if ~exist(img_loc,'file')
            img_loc = fullfile(bsdsRoot,'images','val',[img_name,'.jpg']); 
        end
    end
    img = im2double(imread(img_loc)); [X,Y,~] = size(img);img_size=[X,Y];
    
    out_path = fullfile('./results',img_name);
    if ~exist(out_path,'dir')
        mkdir(out_path);
    end
    
    SpPath = fullfile(bsdsRoot,'Superpixels',img_name,[img_name,'.mat']);
    CovMatPath = fullfile(bsdsRoot,'CovDistance',img_name); % because the file name is different to the distance type.
    
    featPath = make_featPath(SpPath,CovMatPath);
    [seg,labels_img,seg_vals,seg_lab_vals,seg_edges,seg_img]=loadSpSegmentations(SpPath); 

    % save over-segmentations
   % view_oversegmentation(labels_img,seg_img,out_path,img_name);
    %clear labels_img seg_img;

    % build multi-layer bipartite graph  
    B = build_bipartite_graph_grassmann(img_loc,para,seg,seg_lab_vals,seg_edges,featPath);      
    % Transfer Cut
    label_img = Tcut_grassmann(B,Nseg,[X,Y],para);
    
    % save segmentation
    view_segmentation(img,label_img(:),out_path,img_name,0);
    
    % evaluate segmentation
     gt_loc = fullfile(bsdsRoot,'groundTruth','test',[img_name,'.mat']);
    if ~exist(gt_loc,'file')
        gt_loc = fullfile(bsdsRoot,'groundTruth','train',[img_name,'.mat']);
        if ~exist(gt_loc,'file')
            gt_loc = fullfile(bsdsRoot,'groundTruth','val',[img_name,'.mat']); 
        end
    end
    gt = load(gt_loc);
    gt_imgs = cell(1,length(gt.groundTruth));
    for t=1:length(gt_imgs)
        gt_imgs{t} = double(gt.groundTruth{t}.Segmentation);
    end
    out_vals = eval_segmentation(label_img,gt_imgs); 
    fprintf('%6s: %2d %9.6f, %9.6f, %9.6f, %9.6f \n', img_name, Nseg, out_vals.PRI, out_vals.VoI, out_vals.GCE, out_vals.BDE);
    
    PRI_all(idxI) = out_vals.PRI;
    VoI_all(idxI) = out_vals.VoI;
    GCE_all(idxI) = out_vals.GCE;
    BDE_all(idxI) = out_vals.BDE;
    
end

fprintf('Mean: %14.6f, %9.6f, %9.6f, %9.6f \n', mean(PRI_all), mean(VoI_all), mean(GCE_all), mean(BDE_all));


fid_out = fopen(fullfile(bsdsRoot,'evaluation.txt'),'w');
for idxI=1:Nimgs
    fprintf(fid_out,'%6d %9.6f, %9.6f, %9.6f, %9.6f \n', BSDS_INFO(1,idxI), PRI_all(idxI), VoI_all(idxI), GCE_all(idxI), BDE_all(idxI));
end
fprintf(fid_out,'Mean: %10.6f, %9.6f, %9.6f, %9.6f \n', mean(PRI_all), mean(VoI_all), mean(GCE_all), mean(BDE_all));
fclose(fid_out);
