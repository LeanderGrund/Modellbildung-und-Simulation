function G = myUpdate(G,~,dt)

a = G(:,:,1); b = G(:,:,2); c = G(:,:,3); d = G(:,:,4);
solid = G(:,:,end);

for t = 1:dt
    % random bits
    if mod(t-1,32)==0
        z = randi(intmax('uint32'),size(a),'uint32');
    end
    xi = bitget(z,mod(t-1,32)+1);
    % collision
    [a2,b2,c2,d2] = collision(a,b,c,d,xi);
    % fluid/solid fields
    fluid = ~solid;
    a2 = (fluid&a2)|(solid&d);
    b2 = (fluid&b2)|(solid&c);
    c2 = (fluid&c2)|(solid&b);
    d2 = (fluid&d2)|(solid&a);
    % streaming
    [a,b,c,d] = streaming(a2,b2,c2,d2);
end

G(:,:,1) = a; G(:,:,2) = b; G(:,:,3) = c; G(:,:,4) = d;

end

% ------------------------------------------------------------------------

function [a2,b2,c2,d2] = collision(a,b,c,d,xi)

noxi = ~xi;
a2 = xi & b | noxi & c;
b2 = xi & d | noxi & a;
c2 = xi & a | noxi & d;
d2 = xi & c | noxi & b;

end

% ------------------------------------------------------------------------

function [a,b,c,d] = streaming(a,b,c,d)

shift = 1;
a = circshift(a,[-shift  0  0]);
b = circshift(b,[ 0 -shift  0]);
c = circshift(c,[ 0 +shift  0]);
d = circshift(d,[+shift  0  0]);

end

% ------------------------------------------------------------------------