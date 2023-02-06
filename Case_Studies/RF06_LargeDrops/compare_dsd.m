function out = compare_dsd(quicklookfile, numberofbins, ncfile, starttime, endtime);
    % plot dsd for both holodec and cdp on same plot
    st_time = datetime(starttime);
    end_time = datetime(endtime);


    % Holodec Data
    quicklook = load(quicklookfile).pd_out; % loaded structure
    diameters = quicklook.majsiz;
    totalN = length(diameters)

    numbins = numberofbins;
    Dcenters = [];
    N = [];

    % Find total sample volume of all holograms combined
    samples = length(quicklook.counts);
    sample_volume = 13; %cubic cm
    volume = samples*sample_volume;

    Dedges = zeros(numbins+1,1); Dedges(1) = min(diameters); Dedges(end) = max(diameters);
    dD = Dedges(end) - Dedges(1);
    increment = dD/numbins
    for i = 1:numbins
        Dedges(i+1) = Dedges(i) + increment;
        Dcenters(i) = Dedges(i) + increment/2;
    end

    %now go through and find particles
    particlesinbin = zeros(numbins,1);
    for i = 1:numbins
        Dsinbin = find(diameters>=Dedges(i) & diameters<Dedges(i+1)); %Dedges(i) is the lower diameter
        particlesinbin(i) = length(Dsinbin); %this is the number of particle diameters that fell between the bin edges    
    end

    N = particlesinbin./totalN;
    C = particlesinbin./(increment*1000000*volume);
    total_concentration = totalN/volume
    
    holodec_LWC = []
    for i = 1:numbins
        diameter = Dcenters(i)*100; %cm
        d_volume = (4/3)*pi*(diameter/2)^(3); % cubic cm
        bin_water = particlesinbin(i)*d_volume; % g per cubic cm
        holodec_LWC(i) = bin_water;
    end
    
    holodeclwc = sum(holodec_LWC)/(volume*0.000001) %g/m^3

    % figure
    % semilogx(Dcenters.*1000000,N), 
    % xlabel('Diameter (microns)'), ylabel('Probability (Nbin/Ntotal)')
    % title('PDF from SPICULE Holodec')


    %Plot droplet size distribution in #/cc/um
    % figure
    % semilogy(Dcenters.*1000000,C), 
    % xlabel('Diameter (microns)'), ylabel('Concentration (#/cc/micron)')
    % title('DSD from SPICULE Holodec')


    % CDP
    ncfile = fullfile(cd, ncfile);
    if ~exist(ncfile, 'file')
        error('File not found: %s', ncfile);
    end
    
    %Get data from the netCDF file
    time = ncread(ncfile,'time');
    conc = ncread(ncfile, 'PSD');
    binsizes = ncread(ncfile, 'bins');
    cdplwc = ncread(ncfile,'LWC');
    meandiam = ncread(ncfile,'MVD');
    flightnumber = upper(ncreadatt(ncfile, '/', 'NRCFlightNumber'));
    flightdate = ncreadatt(ncfile, '/', 'FlightDate');
    
    %Reshape the concentration array into two dimensions
    s = size(conc);
    conc2 = transpose(conc);
    %Convert from L to cc
    conc2 = conc2./1000;
    s2 = size(conc2);
    
    
    % Reformat time to human readable format
    % Given in netcdf file as seconds since 1970-01-01 +0000
    time2 = datetime(1970,1,1) + seconds(time(:,1));
    
   % select the flight segmennt of interest
   tolerance = duration(0,0,1);
   i_start = datefind(st_time, time2, tolerance);
   i_start = i_start(1);
   i_end = datefind(end_time, time2, tolerance);
   i_end = i_end(1);
   
   time_segment = time2(i_start:i_end);
   conc_segment = conc2(:, i_start:i_end);
   cdplwc_segment = cdplwc(i_start:i_end)
   
   conc_avg = mean(conc_segment, 2, 'omitnan');
   lwc_avg = mean(cdplwc_segment)
   
    
    
   %Plot droplet size distribution in #/cc/um
   figure
   semilogy(binsizes, conc_avg, 'g', Dcenters.*1000000, C, 'b'), legend('CDP', 'Holodec')  
   xlabel('Diameter (microns)'), ylabel('Concentration (#/cc/micron)')
   title('ESCAPE RF06 Updraft Core, CDP & Holodec Droplet Size Distributions')
   grid on
    
   
%     %Make figure
%     figure(1);
%     tiledlayout(4,1);
%     ax1 = nexttile([2 1]);
%     
%     %Concentration contour
%     levels = 10.^(linspace(0,2,20));  %Log10 levels
%     contourf(time, binsizes, conc2, levels, 'LineStyle', 'none');
%     set(gca,'ColorScale','log');
%     grid on
% 
%     xlabel('Time (s)')
%     ylabel('Diameter (microns)');
%     c=colorbar;
%     set(gca,'ColorScale','log');
%     c.Label.String = 'Concentration (#/cc/um)';
%     title([flightnumber ' ' date]);
%     
%     %Mean Diameter
%     ax2 = nexttile;
%     plot(time, meandiam)
%     ylim([0 50])
%     xlabel('Time (s)')
%     ylabel('Dbar (microns)')
%     grid on
%     
%     %LWC
%     ax3 = nexttile;
%     plot(time, cdplwc)
%     ylim([0 2])
%     xlabel('Time (s)')
%     ylabel('LWC (g/m3)')
%     grid on
%     
%     %Link axes for panning and zooming
%     linkaxes([ax1, ax2, ax3],'x');
%     zoom xon;  %Zoom x-axis only
%     pan;  %Toggling pan twice seems to trigger desired behavior, not sure why
%     pan;
    
end
