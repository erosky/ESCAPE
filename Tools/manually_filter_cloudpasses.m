function out = manually_filter_cloudpasses(cloudpassfile, ncfile, cdp_ncfile)
    % Plot a snapshot of cloudpasses of interest
    % manually accept or reject them
    % store data for the accepted passes
    
    %Get data from the aircraft netCDF file
    time = ncread(ncfile,'Time');
    cdplwc_aircraft = ncread(ncfile,'lwc_cdp_sp_rt'); % cdp liquid water content
    nevzlwc = ncread(ncfile, 'lwc_nevz_sp_rt'); % nevzerov liquid water content
    nevztwc = ncread(ncfile, 'twc_nevz_sp_rt'); % nevzerov total water content
    temp = ncread(ncfile,'Ts_rt'); % Static Air Temperature from Rosemount 102 TAT probe on port underwing, in units of degrees Celsius
    vwind = ncread(ncfile,'vwind_rt'); %Vertical windspeed derived from Rosemount 858 airdata probe located on the starboard pylon, in units of metres per second
    icing = ncread(ncfile,'mso_rt');
    alt = ncread(ncfile,'alt_rt'); %m
    lat = ncread(ncfile,'lat_rt');
    lon = ncread(ncfile,'lat_rt');
    
    
    % Reformat time to human readable format
    % Given in netcdf file as seconds since 1970-01-01 +0000
    time2 = datetime(1970,1,1) + seconds(time(:,1));
    
    %Get data from the CDP netCDF file
    time_cdp = ncread(cdp_ncfile,'time');
    conc = ncread(cdp_ncfile, 'PSD');
    cdplwc = ncread(cdp_ncfile,'LWC');
    binsizes = ncread(cdp_ncfile, 'bins');
    binedges = ncread(cdp_ncfile, 'bin_edges');
    flightnumber = upper(ncreadatt(cdp_ncfile, '/', 'NRCFlightNumber'));
    flightdate = ncreadatt(cdp_ncfile, '/', 'FlightDate');

    time2_cdp = datetime(1970,1,1) + seconds(time_cdp(:,1));
    
    %Reshape the concentration array into two dimensions
    s = size(conc);
    conc2 = transpose(conc);
    s2 = size(conc2);
   
    % Open up the cloudpass file
    passes = readtable(cloudpassfile);
    
    % Check each cloudpass
    % Plot snapshot of cdp dsd, lwc, and vertical wind
    % ask user if they want to keep or reject the cloudpass
    % If the user keeps cloudpass, create a new directory, save snapshots
    % to the directory, write aircraft data to a csv file
    
    % Read cloudpasses
    parentFolder = "/home/simulations/Field_Projects/CloudPass_Analysis/ESCAPE";
    
    n=1;
    tempTypes = [];
    summary = table('Size',[0 9],...
                        'VariableTypes',{'datetime','datetime','int8','double','double','double','double','double','double'},...
                        'VariableNames', ["StartTime", "EndTime", "Duration_s", "StartTime_datenum", "EndTime_datenum", "LargeConc_cc", "SmallConc_cc", "MeanDiameter_um", "AverageLWC_g_m3"]);
    
    for row = 1:height(passes);
        pass = passes(row,:)
        largeconc = pass.LargeConc_cc;   
        starttime = pass.StartTime - seconds(2);
        endtime = pass.EndTime + seconds(2);
        logicalIndexes = (time2_cdp <= endtime) & (time2_cdp >= starttime);
        
        logicalIndexes_aircraft = (time2 <= endtime) & (time2 >= starttime);
        
         % Plot properties
         
         fig = figure(1);
         tiledlayout(5,1);
         ax1 = nexttile([2 1]);
% 
%         %Concentration contour
         levels = 10.^(linspace(0,4,20));  %Log10 levels
         contourf(datenum(time2_cdp(logicalIndexes)), binsizes, conc2(:,logicalIndexes), levels, 'LineStyle', 'none');
         datetick('x')
         set(gca,'ColorScale','log');
         grid on
 
         xlabel('Time')
         ylabel('Diameter (microns)');
         c=colorbar;
         set(gca,'ColorScale','log');
         c.Label.String = 'Concentration (#/cc/um)';
         title([flightnumber ' ' date]);
 
         %Vertical Velocity
         ax2 = nexttile;
         plot(datenum(time2(logicalIndexes_aircraft)), vwind(logicalIndexes_aircraft))
         datetick('x')
         xlabel('Time')
         ylabel('Vertical windspeed (m/s)')
         grid on
 
         %LWC
         ax3 = nexttile;
         plot(datenum(time2_cdp(logicalIndexes)), cdplwc(logicalIndexes), 'DisplayName', 'CDP file')
         hold on
         plot(datenum(time2(logicalIndexes_aircraft)), cdplwc_aircraft(logicalIndexes_aircraft), 'DisplayName', 'aircraft file')
         datetick('x')
         xlabel('Time')
         ylabel('LWC (g/m3)')
         legend()
         grid on
         
         %LWC
         ax4 = nexttile;
         plot(datenum(time2(logicalIndexes_aircraft)), temp(logicalIndexes_aircraft))
         datetick('x')
         xlabel('Time')
         ylabel('Temperature (C)')
         legend(sprintf('Large droplets (>15um) = %f', largeconc))
         grid on
 
         %Link axes
         linkaxes([ax1, ax2, ax3, ax4],'x');
         
         % Ask user if we should keep the cloudpass
         prompt = "Save this cloudpass? Y/N: ";
         txt = input(prompt,"s");
         if txt=="Y";
             fprintf("keep\n");
             % Save cloudpass
             RF = split(flightnumber, "-");
             date_txt = string(starttime, 'yyyy-MM-dd-HH-mm-ss') + '_' + string(endtime, 'yyyy-MM-dd-HH-mm-ss');
             passname = RF{2} + "_" + date_txt;
             if all(temp(logicalIndexes_aircraft) >= 0);
                 tempFile = "WarmClouds";
                 if largeconc > 100;
                    concFile = "HighConc";
                 else 
                    concFile = "LowConc";
                 end
                 passFolder = parentFolder + '/' + tempFile + '/' + concFile;
             else
                 tempFile = "ColdClouds";
                 passFolder = parentFolder + '/' + tempFile;
             end
                
             
             % Save figure
             figname = passname + ".png";
             figfile = fullfile(passFolder, figname);
             if ~isfile(figfile)
                 saveas(fig, figfile);
             end
             
             
             % Save data
             % CDP data
             % timestamps, LWC, meandiam, binedges, bincenters, concentration
             cdpname = "cdp_" + passname + ".nc";
             cdpfile = fullfile(passFolder, cdpname);
             if ~isfile(cdpfile)
             
                 nccreate(cdpfile, 'time', "Dimensions", {"time", length(time_cdp(logicalIndexes))}, "Format","classic" );
                 ncwrite(cdpfile, 'time', time_cdp(logicalIndexes));
                 nccreate(cdpfile, 'LWC', "Dimensions", {"time", length(time_cdp(logicalIndexes))});
                 ncwrite(cdpfile, 'LWC', cdplwc(logicalIndexes));
                 nccreate(cdpfile, 'bins', "Dimensions", {"bins", 30});
                 ncwrite(cdpfile, 'bins', binsizes);
                 nccreate(cdpfile, 'bin_edges', "Dimensions", {"bin_edges", 31});
                 ncwrite(cdpfile, 'bin_edges', binedges);
                 nccreate(cdpfile, 'PSD', "Dimensions", {"time", length(time_cdp(logicalIndexes)), "bins", 30});
                 ncwrite(cdpfile, 'PSD', conc(logicalIndexes,:));
             end
             
             
             % Aircraft data csv
             % timestamp, air_temp, vwind, icing, altitude, lat, lon
             output_data = table('Size', [length(time2(logicalIndexes_aircraft)) 0]);
             output_data.Time = time2(logicalIndexes_aircraft);
             output_data.Temperature = transpose(temp(logicalIndexes_aircraft));
             output_data.VerticalWind = transpose(vwind(logicalIndexes_aircraft));
             output_data.Icing = transpose(icing(logicalIndexes_aircraft));
             output_data.Altitude = transpose(alt(logicalIndexes_aircraft));
             output_data.Latitude = transpose(lat(logicalIndexes_aircraft));
             output_data.Longitude = transpose(lon(logicalIndexes_aircraft));
             
             output_filename = fullfile(passFolder, sprintf('aircraft_%s.csv', passname));
             if ~isfile(output_filename)
                writetable(output_data, output_filename);
             end
             
             summary = [summary;pass];
             tempTypes = [tempTypes;tempFile];
             n=n+1;
         end
         
    end
    summary.CloudTemp = tempTypes
    summary_filename = fullfile(parentFolder, sprintf('%s_summary.csv', RF{2}));
    writetable(summary, summary_filename);
    
end