% Class to create object for cloud segments from ESCAPE data
% 2022.11.04
% Nithin Allwayin
% Standard rules used for HOLODEC data:
%   'underthresh','ge',0.1;'dsqoverlz','le',2;'pixden','ge',0.8;
%   'zpos','ge',0.02;'zpos','le',0.155;});

% USAGE:
%       1. segObj = segmentAnalysis(ncfileloc,pdloc)
%       2. segObj = segmentAnalysis(ncfileloc,pdloc,addRules)
%       2. segObj = segmentAnalysis(ncfileloc,pdloc,addRules,cnnmodel)
%
% ncfileloc: location of Convair prelim data
% pdloc    : location of particle data file for segment
% addRules : Additional rules to be applied for the pd
%            e.g. : asprat for warm clouds
% cnnmodel : cnn model to be used

%%


classdef segmentAnalysis
    properties
        convairData = []; % convair data
        pd = []; % HOLODEC Particle data
        noHolograms = 1; % number of holograms grouped together
        volume = 13; %cm^3
        pDiamSelLiquid = 'equivdia'; % equivalend diameter
        pDiamSelIce = 'majsiz'; % 
        drizzlecutoff = 30e-6;  %drizzle cutoff
        
        addRules=[];
        cnnModel=[];
%         fieldnames = [];
        fieldValues=[];
        forCorr = [];
        ice_classes_ind=[];
        ice_classes=[];
        
    end
    methods
        function segObj = segmentAnalysis(ncfileloc,pdloc,addRules,cnnmodel)
            if ~exist('ncfileloc','var') || ~exist('pdloc','var')
                error('Specify location to the Convair nc file/pd object')
            end
            
            % Read data
            [segObj.convairData,segObj.pd] = ...
                segmentAnalysis.readESCAPEData(ncfileloc,pdloc);
            
            % Apply additional rules
            if ~exist('rules','var')
                addRules=[];
            end
            segObj = addAdditionalRules(segObj,addRules);
            
            % Getting fieldvalues
            if ~exist('cnnmodel','var')
                cnnmodel=[];
            end
            segObj = getFieldValues(segObj,cnnmodel);
            
            segObj = forCorrelations(segObj);
        end
        
        function segObj = addAdditionalRules(segObj,addRules)
            if isempty(addRules)
                segObj.addRules = {'underthresh','ge',0.1;...
                    'dsqoverlz','le',2;'pixden','ge',0.8;'zpos',...
                    'ge',0.02;'zpos','le',0.155;};
            else
                segObj.addRules = vertcat(addRules,...
                    {'underthresh','ge',0.1;'dsqoverlz','le',2;...
                    'pixden','ge',0.8;'zpos','ge',0.02;'zpos','le',0.155;});
            end
            
            %Adding additional rules
            for cnt = 1:size(segObj.addRules,1)
                fncn=str2func(segObj.addRules{cnt,2});
                pos = find(strcmp(segObj.pd.prtclmetricvarnames,segObj.addRules{cnt,1}));
                tmp = fncn(segObj.pd.prtclmetrics(:,pos),segObj.addRules{cnt,3});
                segObj.pd.prtclmetrics(~tmp,:)=[];
                segObj.pd.prtclclassify(~tmp,:)=[];
                segObj.pd.holonum(~tmp,:)=[];
                segObj.pd.holotimes(~tmp,:)=[];
                
            end
            
        end
        
        function segObj = getFieldValues(segObj,cnnmodel)
            
            % time = datetime(str, 'InputFormat','yyyy-MM-dd HH:mm');
            time = unique(segObj.pd.holotimes);
            timeUTC = datetime(time,'ConvertFrom','datenum');
            
            % Density of water
            rho_liquid = 997 * 1e3 ; %gm/m^3
            rho_ice = 917 * 1e3 ; %gm/m^3
            
            % Initializations
            segHoloCnt = length(time);
            lwc = nan(segHoloCnt,1);
            dwc = nan(segHoloCnt,1);
            mvd_liquid = nan(segHoloCnt,1);
            numConc_liquid = nan(segHoloCnt,1);
            borders_liquid = 10.^(0.7:0.05:1.9);
            
            
            iwc = nan(segHoloCnt,1);
            mvd_ice = nan(segHoloCnt,1);
            numConc_ice = nan(segHoloCnt,1);
            borders_ice = 10.^(0.7:0.05:2.3);
            
            dCndX_liquid = nan(segHoloCnt,length(borders_liquid)-1);
            dCndX_ice=nan(segHoloCnt,length(borders_ice)-1);
            PDF_liquid = nan(segHoloCnt,length(borders_liquid)-1);
            PDF_ice= nan(segHoloCnt,length(borders_ice)-1);
            
            
            % Creating pd metrics strucutre
            for cnt=1:length(segObj.pd.prtclmetricvarnames)
                pdmetrics.([segObj.pd.prtclmetricvarnames{cnt}]) = ...
                    segObj.pd.prtclmetrics(:,cnt);
            end
            
            % Finding ice and water drops
            if ~isempty(cnnmodel)
                cnnmodel =['/home/nallwayi/SoftwareInstallations/'...
                    'holosuite/predict_pipeline/modelsNN/' cnnmodel];
                cnnloc = find(strcmp(segObj.pd.prtclclassifynames,cnnmodel));
                categories =  segObj.pd.prtclclassify(:,cnnloc);
                segObj.cnnModel = cnnmodel;
            else
                categories =  segObj.pd.prtclclassify(:,end);
                segObj.cnnModel = segObj.pd.prtclclassifynames{end};
            end
            ind_liquid  = find(categories == 'Particle_round');
            
            if length(unique(segObj.pd.prtclclassify(:,1))) > 6
                ice_classes = unique(segObj.pd.prtclclassify(:,1));
                ice_classes(1:6)=[];
                
                segObj.ice_classes=ice_classes;
                ind_ice = [];
                for cnt2=1:length(ice_classes)
                    segObj.ice_classes_ind{cnt2} = ...
                        find(segObj.pd.prtclclassify(:,1)== ice_classes(cnt2));
                    ind_ice =  [ind_ice;segObj.ice_classes_ind{cnt2}];
                end
                
            else
                ind_ice    = find(categories == 'Particle_nubbly');
            end
            
            
            
            % Calculating filed vals
            for cnt = 1:(segHoloCnt)
                
                ind = find(segObj.pd.holotimes == time(cnt));
                
                ind1 = intersect(ind,ind_liquid);
                pDiamLiquid = pdmetrics.([segObj.pDiamSelLiquid])(ind1)*1e6;
                
                ind2 = intersect(ind,ind_ice);
                pDiamIce = pdmetrics.([segObj.pDiamSelIce])(ind2)*1e6;
                
                % Liquid
                if ~isempty(pDiamLiquid) && numel(pDiamLiquid) > 10
                    [meanDiam_liquid, dCndX_liquid(cnt,:)] = ...
                        segmentAnalysis.getDist(pDiamLiquid,'psd',...
                        segObj.volume,segObj.noHolograms,borders_liquid);
                    [~, PDF_liquid(cnt,:)] = ...
                        segmentAnalysis.getDist(pDiamLiquid,'pdf',...
                        segObj.volume,segObj.noHolograms,borders_liquid);
                    
                    %LWC
                    numConc_liquid(cnt) = numel(pDiamLiquid)/segObj.volume;
                    mvd_liquid(cnt) = (mean(pDiamLiquid.^3))^(1/3);
                    lwc(cnt) = rho_liquid* 4/3*pi*sum(pDiamLiquid.^3)...
                        /8/segObj.volume*1e-12; %g/m^3
                    dwc(cnt) = rho_liquid* 4/3*pi*...
                        sum(pDiamLiquid(pDiamLiquid>...
                        segObj.drizzlecutoff*1e6).^3)...
                        /8/segObj.volume*1e-12;%g/m^3
                    
                    xpos_liq{cnt} = pdmetrics.xpos(ind1);
                    ypos_liq{cnt} = pdmetrics.ypos(ind1);
                    zpos_liq{cnt} = pdmetrics.zpos(ind1);
                    segObj.fieldValues.pDiamLiquid{cnt} = pDiamLiquid;
                end
                
                if ~isempty(pDiamIce)
                    [meanDiam_ice, dCndX_ice(cnt,:)] = ...
                        segmentAnalysis.getDist(pDiamIce,'psd',...
                        segObj.volume,segObj.noHolograms,borders_ice);
                    [~, PDF_ice(cnt,:)] = ...
                        segmentAnalysis.getDist(pDiamIce,'pdf',...
                        segObj.volume,segObj.noHolograms,borders_ice);
                    
                    numConc_ice(cnt) = numel(pDiamIce)/segObj.volume;
                    mvd_ice(cnt) = (mean(pDiamIce.^3))^(1/3);
                    iwc(cnt) = rho_ice* 4/3*pi*sum(pDiamIce.^3)...
                        /8/segObj.volume*1e-12;
                    
                    xpos_ice{cnt} = pdmetrics.xpos(ind2);
                    ypos_ice{cnt} = pdmetrics.ypos(ind2);
                    zpos_ice{cnt} = pdmetrics.zpos(ind2);
                    segObj.fieldValues.pDiamIce{cnt} = pDiamIce;
                end
                

                
            end
            
            
            segObj.fieldValues.timeUTC = timeUTC;
            segObj.fieldValues.meanDiam_liquid =meanDiam_liquid;
            segObj.fieldValues.dCndX_liquid =dCndX_liquid;
            segObj.fieldValues.numConc_liquid =numConc_liquid;
            segObj.fieldValues.mvd_liquid =mvd_liquid;
            segObj.fieldValues.lwc =lwc;
            segObj.fieldValues.dwc =dwc;
            segObj.fieldValues.posLiq.xpos = xpos_liq;
            segObj.fieldValues.posLiq.ypos = ypos_liq;
            segObj.fieldValues.posLiq.zpos = zpos_liq;
            
            if exist('meanDiam_ice','var')
                segObj.fieldValues.meanDiam_ice =meanDiam_ice;
                segObj.fieldValues.dCndX_ice =dCndX_ice;
                segObj.fieldValues.PDF_ice =PDF_ice;
                segObj.fieldValues.numConc_ice =numConc_ice;
                segObj.fieldValues.mvd_ice =mvd_ice;
                segObj.fieldValues.iwc =iwc;
                segObj.fieldValues.posIce.xpos = xpos_ice;
                segObj.fieldValues.posIce.ypos = ypos_ice;
                segObj.fieldValues.posIce.zpos = zpos_ice;
            end


            
        end
        
        function segObj = forCorrelations(segObj)
            timeUTC=dateshift(segObj.fieldValues.timeUTC, 'start', 'second');
            
            strtT = find(segObj.convairData.time == timeUTC(1));
            endT = find(segObj.convairData.time == timeUTC(end));
            
            t1 = unique(timeUTC);
            t2 = segObj.convairData.time(strtT:endT);
            
            
            vars = fieldnames(segObj.convairData);
            for cnt=2:length(vars)
                segObj.forCorr.([vars{cnt}]) ...
                    = segObj.convairData.([vars{cnt}])(strtT:endT);
            end
            
            for cnt=1:length(t2)
                ind = find(t2(cnt) == timeUTC);
                vars = fieldnames(segObj.fieldValues);
                for cnt2 = 1:length(vars)
                    if isa(segObj.fieldValues.([vars{cnt2}]),'double') && ...
                            length(segObj.fieldValues.([vars{cnt2}]))== ...
                            length(segObj.fieldValues.timeUTC) && ...
                            size(segObj.fieldValues.([vars{cnt2}]),2) ==1                         
                        if ~isempty(ind)  
                            segObj.forCorr.([vars{cnt2}])(cnt) = ...
                                nanmean(segObj.fieldValues.([vars{cnt2}])(ind));
                        else
                            segObj.forCorr.([vars{cnt2}])(cnt) = nan;
                        end
                    end
                end
            end
            
        end
        
        function plotSegmentFields(segObj)
            
            timeUTC = segObj.fieldValues.timeUTC;
            meanDiam_liquid = segObj.fieldValues.meanDiam_liquid;
            dCndX_liquid = segObj.fieldValues.dCndX_liquid;
            numConc_liquid = segObj.fieldValues.numConc_liquid;
            mvd_liquid = segObj.fieldValues.mvd_liquid;
            lwc = segObj.fieldValues.lwc;
            dwc = segObj.fieldValues.dwc;
            if isfield(segObj.fieldValues,'meanDiam_ice')
                meanDiam_ice = segObj.fieldValues.meanDiam_ice;
                dCndX_ice = segObj.fieldValues.dCndX_ice;
                PDF_ice = segObj.fieldValues.PDF_ice;
                numConc_ice = segObj.fieldValues.numConc_ice;
                mvd_ice = segObj.fieldValues.mvd_ice;
                iwc = segObj.fieldValues.iwc;
            end
            
            % Concentration plots
            figure;
            p = pcolor(timeUTC,meanDiam_liquid,((dCndX_liquid)'));
            set(p,'EdgeColor', 'none');
            colormap('jet')
            title('Liquid');xlabel('UTC');ylabel('dCndX (#/um/cm^3)');
            set(gca,'ColorScale','log');
            plottools;
            
            if exist('meanDiam_ice','var')
                figure;
                p = pcolor(timeUTC,meanDiam_ice,((dCndX_ice)'));
                set(p,'EdgeColor', 'none');
                colormap('jet')
                title('Ice');xlabel('UTC');ylabel('dCndX (#/um/cm^3)');
                set(gca,'ColorScale','log');
                plottools;
                
                
                figure;
                plot(timeUTC,numConc_liquid,'LineWidth',1.5)
                hold on
                xlabel('UTC');ylabel('conc(#/cm^3)');
                yyaxis right
                plot(timeUTC,numConc_ice,'LineWidth',1.5);grid
                title('Time series of Number concentration');
                xlabel('UTC');ylabel('conc(#/cm^3)');
                legend('liquid','ice');plottools
                
            end
            
            % Mixing Plots
            figure
            % plot(numConc_liquid,mvd_liquid*1e6,'.r','MarkerSize',10);pbaspect([1.5 1 1])
            scatter(numConc_liquid,mvd_liquid,20,unique(segObj.pd.holotimes),...
                'filled');pbaspect([1.5 1 1]);colorbar
            xlabel('Nc (#/cm^3)')
            ylabel('Mean volume Diameter(\mum)')
            title('Mixing Diagram-1')
            plottools;
            
            figure
            % plot(numConc_liquid,lwc,'.r','MarkerSize',10);pbaspect([1.5 1 1])
            scatter(numConc_liquid,lwc,20,unique(segObj.pd.holotimes),...
                'filled');pbaspect([1.5 1 1]);colorbar
            xlabel('Nc (#/cm^3)')
            ylabel('Liquid water content (g/m^3)')
            title('Mixing Diagram-2')
            plottools;
            

            figure;
            yyaxis right
            plot(timeUTC,numConc_liquid,'LineWidth',1.5)
            hold on
            xlabel('UTC');ylabel('conc(#/cm^3)');
            yyaxis left
            plot(segObj.convairData.time,...
                segObj.convairData.verticalwind,'LineWidth',1.5);grid
            plot(segObj.convairData.time,...
                segObj.convairData.horizwind,'LineWidth',1.5);grid
            plot(segObj.convairData.time,...
                zeros(1,length(segObj.convairData.time)),'LineWidth',1.5);grid
            title('Time series of Number concentration/Vertical velocity');
            xlabel('UTC');ylabel('w(m/s)');
            xlim([timeUTC(1) timeUTC(end)])
            legend('vertical velocity','horizontal velocity','','num conc');plottools
            
            figure;
            yyaxis right
            plot(timeUTC,numConc_liquid,'LineWidth',1.5)
            hold on
            xlabel('UTC');ylabel('conc(#/cm^3)');
            yyaxis left
            plot(timeUTC,lwc,'LineWidth',1.5);grid
            plot(timeUTC,dwc,'LineWidth',1.5);grid
            plot(segObj.convairData.time,segObj.convairData.cdplwc,...
                'LineWidth',1.5)
            plot(segObj.convairData.time,segObj.convairData.nevzlwc,...
                'LineWidth',1.5)
            title('Time series of Number concentration/lwc');
            xlabel('UTC');ylabel('liquid water content(g/m^3)');
            xlim([timeUTC(1) timeUTC(end)])
            ylim([0 inf])
            legend('lwc','dwc','cdp','nevz','num conc');plottools
            
            figure;
            yyaxis right
            plot(timeUTC,numConc_liquid,'LineWidth',1.5)
            hold on
            xlabel('UTC');ylabel('conc(#/cm^3)');
            yyaxis left
            plot(segObj.convairData.time,segObj.convairData.Ts,...
                'LineWidth',1.5);grid
            title('Time series of Number concentration/temperature');
            xlabel('UTC');ylabel('Air temperature(C)');
            xlim([timeUTC(1) timeUTC(end)])
            legend('air temperature','num conc');plottools
            
            
            
            
        end
        
        function plot3Ddist(segObj,holoId)
            if isa(holoId,'double')
                if holoId <= max(segObj.pd.holonum)
                    holonum=112;
                else
                    error('Invalid hologram number')
                end
            end
            
            fac = 2;
            figure
            scatter3(segObj.fieldValues.posLiq.zpos{holonum}*1e3,...
                segObj.fieldValues.posLiq.xpos{holonum}*1e3...
                ,segObj.fieldValues.posLiq.ypos{holonum}*1e3,...
                segObj.fieldValues.pDiamLiquid{holonum}/fac,...
                segObj.fieldValues.pDiamLiquid{holonum},'filled');
            hold on
            scatter3(segObj.fieldValues.posIce.zpos{holonum}*1e3,...
                segObj.fieldValues.posIce.xpos{holonum}*1e3...
                ,segObj.fieldValues.posIce.ypos{holonum}*1e3,...
                segObj.fieldValues.pDiamIce{holonum}/fac,...
                segObj.fieldValues.pDiamIce{holonum},'filled');
            
            colormap(gca,'jet')
            pbaspect([13 1.5 1.5])
            c=colorbar;
            c.Label.String = 'Diameter (\mum)';
            title(['HOLODEC 3D positions from ' ...
                char(segObj.fieldValues.timeUTC(holonum)) ': Holonum-' ...
                num2str(holonum)])
            xlabel('Z pos (mm)')
            ylabel('x pos (mm)')
            zlabel('y pos (mm)')
        end
        
        function plotCorrelations(segObj,input1,input2)
            
%             y = 0:0.01:max(max(segObj.forCorr.([input2])),...
%                 max(segObj.forCorr.([input1])));
            corrCoeff = corrcoef(segObj.forCorr.([input1]),...
                segObj.forCorr.([input2]),'rows','complete');
            figure
            scatter(segObj.forCorr.([input1]),...
                segObj.forCorr.([input2]),10,'filled');
            lsline
%             hold on
%             plot(y,y,'k','LineWidth',1')
%             hold off
            title(['Correlation plot between ' input1 ' and ' input2 ])
            xlabel(strrep(input1,'_','\_'))
            ylabel(strrep(input2,'_','\_'))
            legend(['corrCoef: ' num2str(corrCoeff(2))])
            pbaspect([1 1 1])
            xlim([-inf max(segObj.forCorr.([input1]))])
            ylim([-inf max(segObj.forCorr.([input2]))])
            plottools
        end
        
        function plotIceHabitConcentrations(segObj)
            if ~isempty(segObj.ice_classes)
                time = unique(segObj.pd.holotimes);
                timeUTC = datetime(time,'ConvertFrom','datenum');
                segHoloCnt = length(timeUTC);
                
                iceHabitCnts=nan(segHoloCnt,length(segObj.ice_classes));
                for cnt=1:segHoloCnt
                    ind = find(segObj.pd.holotimes == time(cnt));
                    for cnt2=1:length(segObj.ice_classes)
                        tmp = ...
                            length(intersect(ind,segObj.ice_classes_ind{cnt2}));
                        if tmp > 0
                            iceHabitCnts(cnt,cnt2) = tmp;
                        end
                    end
                end
                
                figure
                title('ICE habits')
                tiledlayout(3,1)
                ax1 = nexttile
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                for cnt2=1:length(segObj.ice_classes)
                   plot(timeUTC,iceHabitCnts(:,cnt2),'LineWidth',1.5) 
                   hold on
                end
                ax2 = nexttile
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                for cnt2=1:length(segObj.ice_classes)
                   plot(timeUTC,iceHabitCnts(:,cnt2),'LineWidth',1.5) 
                   hold on
                end
                ax3 = nexttile
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                for cnt2=1:length(segObj.ice_classes)
                   plot(timeUTC,iceHabitCnts(:,cnt2),'LineWidth',1.5) 
                   hold on
                end
                hold off
                xlabel('timeUTC')
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                
                figure
                title('ICE habits')
                tiledlayout(3,1)
                ax1 = nexttile
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                for cnt2=1:length(segObj.ice_classes)
                    plot(1:length(timeUTC),...
                        iceHabitCnts(:,cnt2),'LineWidth',1.5)
                    hold on
                end
                ax2 = nexttile
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                for cnt2=1:length(segObj.ice_classes)
                    plot(1:length(timeUTC),...
                        iceHabitCnts(:,cnt2),'LineWidth',1.5)
                    hold on
                end
                ax3 = nexttile
                ylabel('count per Hologram')
                legend(segObj.ice_classes)
                for cnt2=1:length(segObj.ice_classes)
                    plot(1:length(timeUTC),...
                        iceHabitCnts(:,cnt2),'LineWidth',1.5)
                    hold on
                end
                hold off
                xlabel('timeUTC')
                ylabel('count per Hologram')
            else
                sprintf('No hand classified ice particles')
            end
            
        end
    end
    
    methods(Static)
        
        function [convairData,pd] = readESCAPEData(ncfileloc,pdloc)
            % convair file
            ncfileList = dir(fullfile(ncfileloc,'*.nc'));
            ncfile =fullfile(ncfileList.folder,ncfileList.name);
            try
                convairData = segmentAnalysis.getConvairPrelimData(ncfile);
            catch
                error('Could not read the Convair nc file')
            end
            try
                load([pdloc '/pd.mat'],'pd');
            catch
                error('Could not read particle data file')
            end
            
        end
        
        function convairData = getConvairPrelimData(ncfile)
            convairData.metadata = ncinfo(ncfile);
            convairData.time = ncread(ncfile,'Time');
            convairData.time = datetime(convairData.time, 'convertfrom',...
                'posixtime', 'Format', 'MM/dd/yy HH:mm:ss.SSS');
            convairData.cdplwc = ncread(ncfile,'lwc_cdp_sp_rt'); % cdp liquid water content
            convairData.nevzlwc = ncread(ncfile, 'lwc_nevz_sp_rt'); % nevzerov liquid water content
            convairData.verticalwind = ncread(ncfile, 'vwind_rt');%Vertical windspeed
            convairData.Ts = ncread(ncfile, 'Ts_rt');%Static air temperature
            convairData.horizwind = ncread(ncfile, 'hwspd_rt');
        end
        
        
        
        % Function to get the PDF/PSD of the diameter distribution
        % It can handle second scale data with proper input
        function [meanDiam, dist] = getDist(pDiam,mode,volume,noHolograms,borders)
            
            histBinBorder = borders;
            histBinWidth = histBinBorder(2:end)-histBinBorder(1:end-1);
            histMeanDiam = 0.5*(histBinBorder(2:end)+histBinBorder(1:end-1));
            meanDiam = histMeanDiam;
            
            switch mode
                case 'pdf'
                    %calculate the probability density function
                    PDF = histcounts(pDiam,histBinBorder);
                    PDF = PDF/sum(PDF)/volume/noHolograms;
                    PDFNorm= PDF./histBinWidth;
                    PDF = PDFNorm;
                    dist  = PDF;
                case 'psd'
                    %calculate the particle size distribution
                    PSD = histcounts(pDiam,histBinBorder)/volume/noHolograms;
                    PSDNorm= PSD./histBinWidth;
                    dCndX = PSDNorm;
                    dist  = dCndX;
            end
            
        end
    end
    
    
end