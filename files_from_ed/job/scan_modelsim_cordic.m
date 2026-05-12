clc; clear; clf; 

fid=fopen('cordic.dat','r');
%fid=fopen('res_dem.dat','r');
 data=fread(fid,5000,'int32');
fclose(fid)
    
for k=0:length(data)/2-1
qr(k+1)=data(1+2*k);
qi(k+1)=data(2+2*k);
end

 s=qr+1i*qi;
 
 s=s'.*hann(length(s));
 
 sp=fft(s);
 sp=sp.*conj(sp);
 sp=10*log10(sp);
 
 
 
 
 
 plot(sp-max(sp));grid;

