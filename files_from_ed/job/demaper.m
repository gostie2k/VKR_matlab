function res = demaper(s)

for i=0:7
si(i+1)=exp(1i*pi*i/4);
end
sig=1/8;

for k=1:length(s)
ph=atan2(imag(s(k)),real(s(k)));
if (ph<0) ph=ph+2*pi;end
d_ph(k)=round(ph/(pi/4));
if (d_ph(k) == 8) d_ph(k)=0; end

for n=1:8
  P(n)=exp( -abs(s(k)-si(n))^2/(2*sig^2) )/ sqrt(2*sig^2);
  PP(n)=abs(s(k)-si(n))^2;%-abs(s(k)-si(n))^2/(2*sig^2);
end

b2(k)=log((P(1)+P(2)+P(3)+P(4))/(P(5)+P(6)+P(7)+P(8)));
b1(k)=log((P(1)+P(2)+P(5)+P(6))/(P(3)+P(4)+P(7)+P(8)));
b0(k)=log((P(1)+P(3)+P(5)+P(7))/(P(2)+P(4)+P(6)+P(8)));

bb2(k)=max([PP(1),PP(2),PP(3),PP(4)])-max([PP(5),PP(6),PP(7),PP(8)]);
bb1(k)=max([PP(1),PP(2),PP(5),PP(6)])-max([PP(3),PP(4),PP(7),PP(8)]);
bb0(k)=max([PP(1),PP(3),PP(5),PP(7)])-max([PP(2),PP(4),PP(6),PP(8)]);

res(k,:)=[d_ph(k),b2(k),b1(k),b0(k),bb2(k),bb1(k),bb0(k),PP(1),PP(2),PP(3),PP(4),PP(5),PP(6),PP(7),PP(8), ph*180/pi]

s(k)
pause
end




