clc;clear all; clf;
fid=fopen('out.dat','r');
data=fread(fid,4096*2,'double');
fclose(fid);
   
v = rcosdesign(.2, 10, 4,'sqrt');
    
for k=0:length(data)/2-1
dr(k+1)=data(1+2*k);
di(k+1)=data(2+2*k);
end

%t=1:length(data)/2;
%plot(t,dr,'.r-',t,di,'ob-');
% 
%  plot(dr,di,'.m');
%  grid;
%  pause


s=dr+1i*di;

sant=s;


s=s/max(abs(s));

s=s.*exp(-1i*2*pi*(1:length(s))/4);

%sp=fft(s);
%sp=sp.*conj(sp);
%sp=10*log10(sp);
%plot(sp)
%pause


v=round(v/max(v)*8192);

ssf=filter(v,1,s);
ssf=ssf(length(v):length(ssf));


s=gen_8PSK(35000,8);


%s=s(6:end)+s(4:end-2)/4;

%s=s+max(abs(s))*(rand(1,length(s))-.5+rand(1,length(s))*1i-0.5*1i)/5;

%s=s.*exp(2*pi*1i*(1:length(s))/12/10^6*1111);

s=s/max(abs(s));
s=s';

ssf=s;
 

% mm=4;
% lf=10;
% 
% symbolSync = comm.SymbolSynchronizer(...
%     'SamplesPerSymbol',mm, ...
%     'NormalizedLoopBandwidth',0.01, ...
%     'DampingFactor',1.0, ...
%     'TimingErrorDetector','Gardner (non-data-aided)',...
%     'Modulation',"PAM/PSK/QAM",...
%     'DetectorGain',2.7);
% 
% %  txfilter = comm.RaisedCosineTransmitFilter( ...
% %      'RolloffFactor',0.22,...
% %      'FilterSpanInSymbols',lf,...
% %      'Shape','Square root',...
% %      'OutputSamplesPerSymbol',mm);
% %  rxfilter = comm.RaisedCosineReceiveFilter( ...
% %      'RolloffFactor',0.22,...
% %      'FilterSpanInSymbols',lf,...
% %      'Shape','Square root',...
% %      'InputSamplesPerSymbol',mm,'DecimationFactor',1);
% %sf=txfilter(s);
% %ssf=rxfilter(sf);
% 
% sym=symbolSync(ssf);
% scatterplot(sym(14000:end),1);
% pause



for k=0:length(ssf)-1
ssfx2(1+2*k)=ssf(k+1);
ssfx2(2+2*k)=0;
end
ssfx2f=filter(int_x2,1,ssfx2);
ssfx2f=ssfx2f(length(int_x2):length(ssfx2f));


for k=0:length(ssfx2f)-1
ssfx2fx5(1+5*k)=ssfx2f(k+1);
ssfx2fx5(2+5*k)=0;
ssfx2fx5(3+5*k)=0;
ssfx2fx5(4+5*k)=0;
ssfx2fx5(5+5*k)=0;
end

ssfx2fx5f=filter(int_x5,1,ssfx2fx5);
ssfx2fx5f=ssfx2fx5f(length(int_x5):length(ssfx2fx5f));







m=40;
sss=ssfx2fx5f;
%sss=s;


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
    %tmp=tmp.*exp(-1i*pi/8);
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
  %tmp=tmp.*exp(-1i*pi/8);
  tmp=tmp/mean(abs(tmp));
  plot(tmp,'.'); 
  text(-0.5,0,strcat('MER = ',num2str(mer(k)),' dB') );
  grid on;

pause(1);

sss=sss/mean(abs(sss));

sss=sss/4;

%sss=sss/(mean(abs(sss).^2)*4);

dr=real(sss);
di=imag(sss);
%plot(1:length(dr),dr,'.b-',1:length(di),di,'or-');

%sp=fft(ssfx2fx5f);
%sp=sp.*conj(sp);
%sp=10*log10(sp);
%plot(sp)
%pause

%  g=2;
%  for k=21:g*40+20    
%      er(k)=dr(k)*(dr(k-20)-dr(k+20));
%      ei(k)=di(k)*(di(k-20)-di(k+20));
%      eror(k-20)=er(k)+ei(k);
%  end
 
 %plot(eror);grid;
 %pause;






e=0;
ie=0;
index=41;
k=1;
per=40;
dper=0;
vi=0;
nco=1/40;
K1=-5.4*10^-4;%-2.4*10^-3;
K2=-8.2*10^-6;%-8.2*10^-6;

K1=-2^-2;
K2=-2^-5;

% %for  k=1:length(dr)/40-2 
% while ((index<length(dr))&&(index-round(per/2)<length(dr))&&(index-round(per)<length(dr)))
%     
% %     if (sign( dr(index-round(per)) ) == sign( dr(index) ) )
% %      er(k)= 0;
% %     else
% %      er(k)=dr(index-round(per/2))*(dr(index-round(per))-dr(index));
% %     end
% %     
% %     
% %     if (sign( di(index-round(per)) ) == sign( di(index) ) )
% %      ei(k)= 0;
% %     else
% %      ei(k)=di(index-round(per/2))*(di(index-round(per))-di(index));
% %     end
%     
%     er(k)=dr(index-round(per/2))*(dr(index-round(per))-dr(index));
%     ei(k)=di(index-round(per/2))*(di(index-round(per))-di(index));
%   
%     
%     %er(k)=int_l(dr,index-round(per/2),-dper/2-per/2+round(per/2))*(int_l(dr,index-round(per),-dper)-int_l(dr,index,dper));
%     %ei(k)=int_l(di,index-round(per/2),-dper/2-per/2+round(per/2))*(int_l(di,index-round(per),-dper)-int_l(di,index,dper));
% 
%     
%     e=er(k)+ei(k);
%     vp=K1*e;
%     vi=vi+K2*e;
%     v=vp+vi; 
%     per=40-v+dper;
%     
%     dsa(k)=int_l(dr,index,dper)+1i*int_l(di,index,dper);
%     dindex(k)=index+dper;
%     
%     %dsa(k)=dr(index)+1i*di(index);
%     %dindex(k)=index;
%     
%     index=index+round(per);
%     dper=per-round(per);
%     
%     %dper=round(dper*16)/16;
%     
%     err(k)=dper;
%     
%     k=k+1;
% end

dr_last=0;
di_last=0;
K1=-2^-2;
K2=-2^-8;

K1=K1*1;
K2=K2*1;

lock=0;
cnt=1;
e=0;
k=1;
dper=0;
per=40;
vi=0;

Kagc=1;
Bagc=2^-2;


for  ii=2:length(dr)-42 
    %dr(ii)=dr(ii)*Kagc;
    %di(ii)=di(ii)*Kagc;
    
    if (cnt == round(per))
    %er(k)=dr(index-round(per/2))*(dr_last-dr(index));
    %ei(k)=di(index-round(per/2))*(di_last-di(index));
    
    drr=dr(ii)*Kagc;
    dii=di(ii)*Kagc;
            
    %drr=int_l(dr,ii,dper,Kagc);
    %dii=int_l(di,ii,dper,Kagc)   
    
    %dsa(k)=drr+1i*dii;
    %dindex(k)=ii+dper;
    
    er(k)=dr_half*(dr_last-drr);
    ei(k)=di_half*(di_last-dii);
    dr_last=drr;
    di_last=dii;
    e=er(k)+ei(k);
    vp=K1*e;
    vi=vi+K2*e;
    v=vp+vi; 
    per=40-v+dper;
    
    %dsa(k)=int_l(dr,ii,dper,Kagc)+1i*int_l(di,ii,dper,Kagc);
    %dindex(k)=index+dper;
    
    dsa(k)=drr+1i*dii;
    dindex(k)=ii+dper;
    
    %Kagc=Kagc+Bagc*(1-abs(dsa(k)));
    
    Kagc=Kagc+Bagc*(1-abs(dsa(k))^2);
    
     %index=index+round(per);
    dper=per-round(per);
    
    dper=round(dper*256)/256;
   
    err(k)=Kagc;
    
    k=k+1;  
    cnt=1; 
    else
        
    if (cnt==round(per/2))
        
    dr(ii)=dr(ii)*Kagc;
    di(ii)=di(ii)*Kagc;  
        
     dr_half=dr(ii);
     di_half=di(ii);     
    end 
                    
     cnt=cnt+1; 
    end
    

    
    
    
    
    
    
end







% 
% 
% x=dr;
% CNT_next=0;
% mu_next=0;
% k=1;
% underflow=0;
% TEDBuff=[0,0];
% for n=4:length(dr)-2
%     
% CNT=CNT_next;
% mu=mu_next;
% 
% v2=1/2*[1,-1,-1,1]*x(n:-1:n-3)';
% v1=1/2*[-1,3,-1,-1]*x(n:-1:n-3)';
% v0=x(n-2);
% XI=(mu*v2+v1)*mu+v0;
% if underflow ==1
%  xx(k)=XI;
%  k=k+1;
% end
% 
% if (underflow == 1)
%  e=TEDBuff(1)*(TEDBuff(2)-XI);
% else 
%  e=0;
% end
% 
% vp=K1*e;
% vi=vi+K2*e;
% v=vp+vi;
% W=1/40+v;
% 
% CNT_next=CNT-W;
% if CNT_next<0
%    CNT_next=1+CNT_next;
%    underflow=1;
%    mu_next=CNT/W;    
% else
%     underflow=0;
%     mu_next=mu;
% end
% 
% TEDBuff=[XI,TEDBuff(1)];
% 
% 
% end
% 
% 
% 
% plot(xx)
% pause




plot(err,'.b-');grid; 
plot(1:length(sss),real(sss),'.r-',dindex,real(dsa),'ob'); 
 
  
yy=15000;
dsa=dsa(yy:end);
tmp=dsa;
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






%demaper(dsa);





test=round(sss*(2^13-1));

fid=fopen('test.dat','w+');
for k=1:length(test)
 fwrite(fid,real(test(k)),'int16');
 fwrite(fid,imag(test(k)),'int16');
end
fclose(fid);


% fid=fopen('result.dat','r');
%  data=fread(fid,35000*40*4,'int16');
% fclose(fid)
%     
% for k=0:length(data)/2-1
% qr(k+1)=data(1+2*k);
% qi(k+1)=data(2+2*k);
% end
