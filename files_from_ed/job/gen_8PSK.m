function s = gen_8PSK(n,m)
% n - symbol count
% m - PSK type   -> m-PSK


data=round(rand(1,n)*(m-1));

s=round(exp(2*1i*pi*(0:m-1)/m)*(2^11-1));
if (m==8)
 m_8_psk=[s(2), s(1), s(5), s(6), s(3), s(8), s(4), s(7)];
 syms=m_8_psk(data+1);
end
if (m==4)
 m_qpsk=exp(1i*pi/4)*[s(1), s(2), s(4), s(3)];
 syms=m_qpsk(data+1);
end
if (m==2)
 m_bpsk=[s(1), s(2)];
 syms=m_bpsk(data+1);
end

if (m==1)
 f=1;
 for k=1:n
  if (f==1)
   f=-1;
  else
   f=1;    
  end
 syms(k)=f;
 end

end
%s=syms;


for k=1:n
s(1+4*k)=syms(k);   
s(2+4*k)=0; 
s(3+4*k)=0; 
s(4+4*k)=0; 
end

v = rcosdesign(.2, 10, 4,'sqrt');

s=filter(v,1,s);
s=s(length(v):length(s));
s=filter(v,1,s);
s=s(length(v):length(s));


% 
% index=2;
% for k=3:length(s)-3
%    index=index+0.999;
%    n=round(index);
%    
%    xi=(n-2:n+2)-n;
%    yi=s(n-2:n+2);
%    p=polyfit(xi,yi,3);
%    ss(k-2)=polyval(p,index-n);
% end
% 
% s=ss;







