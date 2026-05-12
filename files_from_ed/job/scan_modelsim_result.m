clc; clear; clf; 

fid=fopen('result.dat','r');
%fid=fopen('res_dem.dat','r');
 data=fread(fid,(35000-100)*2,'int16');
fclose(fid)
    
for k=0:length(data)/2-1
qr(k+1)=data(1+2*k);
qi(k+1)=data(2+2*k);
end

s=qr+1i*qi;




yy=15000;
dsa=s(yy:end);
tmp=dsa/(2^13-1);
%tmp=tmp/mean(abs(tmp));

plot(real(tmp),imag(tmp),'.m');

an=180/pi*atan2(imag(tmp),real(tmp));
an=an/45;
an=round(an);
an=an*45;
an=an*pi/180;
dem_solve=exp(1i*an);
mer=20*log10(mean(abs(tmp-dem_solve)));

text(-0.5,0,strcat('MER = ',num2str(mer),' dB') );
grid on;