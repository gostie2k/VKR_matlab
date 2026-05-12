clc;clear all; 
fid=fopen('out.dat','r');
data=fread(fid,4096*2,'double');
fclose(fid);

% txfilter = comm.RaisedCosineTransmitFilter( ...
%     'RolloffFactor',0.22,...
%     'FilterSpanInSymbols',15,...
%     'Shape','Square root',...
%     'OutputSamplesPerSymbol',4);
% rxfilter = comm.RaisedCosineReceiveFilter( ...
%     'RolloffFactor',0.22,...
%     'FilterSpanInSymbols',15,...
%     'Shape','Square root',...
%     'InputSamplesPerSymbol',4,'DecimationFactor',1);
    
v = rcosdesign(.2, 10, 4,'sqrt');
    


for k=0:length(data)/2-1
dr(k+1)=data(1+2*k);
di(k+1)=data(2+2*k);
end

%t=1:length(data)/2;
%plot(t,dr,'.r-',t,di,'ob-');
s=dr+1i*di;
s=s/max(abs(s));
%s =s.*exp(-1i*2*pi*(1:length(s))/4);

ss=s;

%sp=fft(s);
%sp=sp.*conj(sp);
%sp=10*log10(sp);
%plot(sp)
%pause

s=s';

s=cat(1,s,s);
s=cat(1,s,s);
s=cat(1,s,s);
s=cat(1,s,s);




txSig =s;
%txSig = txfilter(s);
%txSig = filter(v,1,s);
%txSig=s.*exp(1i*2*pi*(1:length(s))/4)';
%txSig=cat(1,0,txSig);

%sp=fft(txSig);
%sp=sp.*conj(sp);
%sp=10*log10(sp);
%plot(sp)
%pause

%rxSample = rxfilter(txSig);  
rxSample = filter(v,1,txSig);

%rxSample = s;

symbolSync = comm.SymbolSynchronizer(...
    'SamplesPerSymbol',4, ...
    'NormalizedLoopBandwidth',0.01, ...
    'DampingFactor',1.0, ...
    'TimingErrorDetector','Gardner (non-data-aided)',...
    'Modulation',"PAM/PSK/QAM",...
    'DetectorGain',2.7);

   %'TimingErrorDetector','Gardner (non-data-aided)',...
   %'TimingErrorDetector','Zero-Crossing (decision-directed)',...
   % 'TimingErrorDetector','Early-Late (non-data-aided)',... 

%symbolSync = comm.SymbolSynchronizer('Modulation',"PAM/PSK/QAM");


sym=symbolSync(rxSample);
%sym=symbolSync(s);
scatterplot(sym(5401:end),1);
%plot(sym(5401:end),'.b');

%pause









v=round(v*(2^15-1));
v=v/(2^15-1);
ssf=filter(v,1,ss);
ssf=ssf(length(v):length(ssf));

ssf=ss;

for k=0:length(ssf)-1
ssfx2(1+2*k)=ssf(k+1);
ssfx2(2+2*k)=0;
end
ssfx2f=filter(int_x2,1,ssfx2);
ssfx2f=ssfx2f(length(int_x2):length(ssfx2f));

% for k=0:length(ssfx2f)-1
% ssfx2fx5(1+5*k)=ssfx2f(k+1);
% ssfx2fx5(2+5*k)=0;
% ssfx2fx5(3+5*k)=0;
% ssfx2fx5(4+5*k)=0;
% ssfx2fx5(5+5*k)=0;
% end


for k=0:length(ssfx2f)-1
ssfx2fx2(1+2*k)=ssfx2f(k+1);
ssfx2fx2(2+2*k)=0;
end

ssfx2fx2f=filter(int_x2,1,ssfx2fx2);
ssfx2fx2f=ssfx2fx2f(length(int_x2):length(ssfx2fx2f));



% for k=0:length(ssfx2fx2f)-1
% ssfx2fx2fx2(1+2*k)=ssfx2fx2f(k+1);
% ssfx2fx2fx2(2+2*k)=0;
% end
% 
% ssfx2fx2fx2f=filter(int_x2,1,ssfx2fx2fx2);
% ssfx2fx2fx2f=ssfx2fx2fx2f(length(int_x2):length(ssfx2fx2fx2f));
% 
% 










m=16;
sss=ssfx2fx2f;


for k=0:m-1

    for i=1:length(sss)/m
     tmp(i)=sss(1+k+(i-1)*m);
    end
    
    atmp=angle(tmp);
    
    atmp=atmp-fix(atmp/(pi/4));
    %plot(atmp,'.b-');grid;pause; 
     
    tmp=tmp/mean(abs(tmp));
    ca=mean(atmp);
    
    %plot(tmp,'.');
    %pause
    
    tmp=tmp.*exp(-1i*ca);
    tmp=tmp.*exp(-1i*pi/8);
    %'cor'   
    plot(tmp,'.');
    %pause
    
    an=180/pi*atan2(imag(tmp),real(tmp));
    an=an/45;
    an=round(an);
    an=an*45;
    an=an*pi/180;
    dem_solve=exp(1i*an);
    %k+1
    mer(k+1)=20*log10(mean(abs(tmp-dem_solve)));
    %pause
end

max(-mer)
for k=1:length(mer)
  if (max(-mer)==-mer(k))
      break;
  end
end

k


  for i=1:length(sss)/m
     tmp(i)=sss(k+(i-1)*m);
  end
  
  atmp=angle(tmp);
  atmp=atmp-fix(atmp/(pi/4));
  ca=mean(atmp);
  tmp=tmp.*exp(-1i*ca);
  tmp=tmp.*exp(-1i*pi/8);
  tmp=tmp/mean(abs(tmp));
  plot(tmp,'.'); 
  text(-0.5,0,strcat('MER = ',num2str(mer(k)),' dB') );
  grid on;

















sp=fft(ssfx2fx5);
sp=sp.*conj(sp);
sp=10*log10(sp);
%plot(sp)





