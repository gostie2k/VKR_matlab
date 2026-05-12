clear; clc;
M = 8;         % Modulation order for QPSK
nSym = 2000;   % Number of symbols in a packet
sps = 2;       % Samples per symbol
timingErr = sps/2; % Samples of timing error
snr = 15;      % Signal-to-noise ratio (dB)

txfilter = comm.RaisedCosineTransmitFilter( ...
    'OutputSamplesPerSymbol',sps);
rxfilter = comm.RaisedCosineReceiveFilter( ...
    'InputSamplesPerSymbol',sps,'DecimationFactor',sps/2);

%symbolSync = comm.SymbolSynchronizer;


symbolSync = comm.SymbolSynchronizer(...
    'SamplesPerSymbol',2, ...
    'NormalizedLoopBandwidth',0.01, ...
    'DampingFactor',1.0, ...
    'TimingErrorDetector','Gardner (non-data-aided)');




data = randi([0 M-1],nSym,1);
modSig = pskmod(data,M,pi/4);

fixedDelay = dsp.Delay(timingErr);
fixedDelaySym = ceil(fixedDelay.Length/sps); % Round fixed delay to nearest integer in symbols

txSig = txfilter(modSig);
delaySig = fixedDelay(txSig);

rxSig = delaySig;%awgn(delaySig,snr,'measured');

rxSample = rxfilter(rxSig);  
scatterplot(rxSample(1001:end),2);pause;

rxSync = symbolSync(rxSample);
scatterplot(rxSync(1001:end),2);

recData = pskdemod(rxSync,M,pi/4);


sysDelay = dsp.Delay(fixedDelaySym + txfilter.FilterSpanInSymbols/2 + ...
    rxfilter.FilterSpanInSymbols/2);

[numErr,ber] = biterr(sysDelay(data),recData)