clc;clear all; clf;
fid=fopen('out.dat','r');
data=fread(fid,4096*2,'double');
fclose(fid);
   
v = rcosdesign(.2, 10, 4,'sqrt');
    
for k=0:length(data)/2-1
dr(k+1)=data(1+2*k);
di(k+1)=data(2+2*k);
end

s=dr+1i*di;




yy=1;
dsa=s(yy:end);
tmp=dsa;
tmp=tmp/mean(abs(tmp));

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





s=round((2^11-1)*s/max(real(s)));

hex(fi(s,1,12,0))


