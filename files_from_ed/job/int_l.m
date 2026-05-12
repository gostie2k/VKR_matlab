function s = int_l(y,x,dx,K)


if (dx>=0)
   s=y(x)+(y(x+1)-y(x))*dx; 
end

if (dx<0)
  s=y(x)+(y(x)-y(x-1))*dx;   
end

s=s*K;

% if (x>100)
% xi=[-2,-1,0,1,2];
% yi=[y(x-2),y(x-1),y(x),y(x+1),y(x+2)];
% p=polyfit(xi,yi,2);
% s = polyval(p,dx);
% else
% s=0;
% end
    