const { ethers } = require("hardhat");

const DECIMALS = 18;
const parseUnits = (__num) =>
  ethers.utils.parseUnits(__num.toString(), DECIMALS);

const hexToDecimal = (hex) => parseInt(hex, 16);

const h2d = s => {

  function add(x, y) {
    var c = 0, r = [];
    var x = x.split('').map(Number);
    var y = y.split('').map(Number);
    while (x.length || y.length) {
      var s = (x.pop() || 0) + (y.pop() || 0) + c;
      r.unshift(s < 10 ? s : s - 10);
      c = s < 10 ? 0 : 1;
    }
    if (c) r.unshift(c);
    return r.join('');
  }

  var dec = '0';
  s.split('').forEach(function(chr) {
    var n = parseInt(chr, 16);
    for (var t = 8; t; t >>= 1) {
      dec = add(dec, dec);
      if (n & t) dec = add(dec, '1');
    }
  });
  return dec;
}

module.exports = {
  parseUnits,
  h2d,
  DECIMALS,
  hexToDecimal,
};
