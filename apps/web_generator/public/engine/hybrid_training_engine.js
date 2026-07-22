(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.lK(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.j(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.hR(b)
return new t(c,this)}:function(){if(t===null)t=A.hR(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.hR(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
hU(a,b,c,d){return{i:a,p:b,e:c,x:d}},
hd(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.hS==null){A.lA()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.a(A.iw("Return interceptor for "+A.A(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.fQ
if(p==null)p=$.fQ=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.lF(a)
if(q!=null)return q
if(typeof a=="function")return B.aW
t=Object.getPrototypeOf(a)
if(t==null)return B.K
if(t===Object.prototype)return B.K
if(typeof r=="function"){p=$.fQ
if(p==null)p=$.fQ=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.v,enumerable:false,writable:true,configurable:true})
return B.v}return B.v},
jO(a,b){if(a<0||a>4294967295)throw A.a(A.ap(a,0,4294967295,"length",null))
return J.jP(new Array(a),b)},
ia(a,b){return A.j(new Array(a),b.i("l<0>"))},
jP(a,b){var t=A.j(a,b.i("l<0>"))
t.$flags=1
return t},
jQ(a,b){var t=u.e8
return J.jt(t.a(a),t.a(b))},
ib(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
jR(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.ib(s))break;++b}return b},
jS(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.b(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.ib(r))break}return b},
bx(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.ch.prototype
return J.dn.prototype}if(typeof a=="string")return J.bd.prototype
if(a==null)return J.ci.prototype
if(typeof a=="boolean")return J.dm.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.aF.prototype
if(typeof a=="symbol")return J.bI.prototype
if(typeof a=="bigint")return J.bH.prototype
return a}if(a instanceof A.e)return a
return J.hd(a)},
hc(a){if(typeof a=="string")return J.bd.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.aF.prototype
if(typeof a=="symbol")return J.bI.prototype
if(typeof a=="bigint")return J.bH.prototype
return a}if(a instanceof A.e)return a
return J.hd(a)},
b_(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.aF.prototype
if(typeof a=="symbol")return J.bI.prototype
if(typeof a=="bigint")return J.bH.prototype
return a}if(a instanceof A.e)return a
return J.hd(a)},
lu(a){if(typeof a=="number")return J.bG.prototype
if(typeof a=="string")return J.bd.prototype
if(a==null)return a
if(!(a instanceof A.e))return J.bV.prototype
return a},
lv(a){if(a==null)return a
if(typeof a!="object"){if(typeof a=="function")return J.aF.prototype
if(typeof a=="symbol")return J.bI.prototype
if(typeof a=="bigint")return J.bH.prototype
return a}if(a instanceof A.e)return a
return J.hd(a)},
N(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.bx(a).a_(a,b)},
jp(a,b){if(typeof b==="number")if(Array.isArray(a)||A.lD(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.b_(a).h(a,b)},
c1(a,b,c){return J.b_(a).l(a,b,c)},
jq(a,b){return J.b_(a).N(a,b)},
jr(a){return J.lv(a).bf(a)},
js(a,b){return J.b_(a).ac(a,b)},
jt(a,b){return J.lu(a).Y(a,b)},
hn(a,b){return J.b_(a).C(a,b)},
e9(a){return J.bx(a).gD(a)},
hX(a){return J.hc(a).gv(a)},
ju(a){return J.b_(a).gV(a)},
O(a){return J.b_(a).gn(a)},
c2(a){return J.hc(a).gp(a)},
jv(a){return J.bx(a).gF(a)},
a3(a,b,c){return J.b_(a).a8(a,b,c)},
b1(a){return J.bx(a).m(a)},
dk:function dk(){},
dm:function dm(){},
ci:function ci(){},
cj:function cj(){},
aL:function aL(){},
dE:function dE(){},
bV:function bV(){},
aF:function aF(){},
bH:function bH(){},
bI:function bI(){},
l:function l(a){this.$ti=a},
dl:function dl(){},
eO:function eO(a){this.$ti=a},
b2:function b2(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bG:function bG(){},
ch:function ch(){},
dn:function dn(){},
bd:function bd(){}},A={ht:function ht(){},
i3(a,b,c){if(u.Y.b(a))return new A.cJ(a,b.i("@<0>").u(c).i("cJ<1,2>"))
return new A.b3(a,b.i("@<0>").u(c).i("b3<1,2>"))},
iu(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
kb(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ll(a,b,c){return a},
hT(a){var t,s
for(t=$.ag.length,s=0;s<t;++s)if(a===$.ag[s])return!0
return!1},
jY(a,b,c,d){if(u.Y.b(a))return new A.ca(a,b,c.i("@<0>").u(d).i("ca<1,2>"))
return new A.bh(a,b,c.i("@<0>").u(d).i("bh<1,2>"))},
bF(){return new A.bR("No element")},
hr(){return new A.bR("Too many elements")},
aU:function aU(){},
c5:function c5(a,b){this.a=a
this.$ti=b},
b3:function b3(a,b){this.a=a
this.$ti=b},
cJ:function cJ(a,b){this.a=a
this.$ti=b},
cI:function cI(){},
aC:function aC(a,b){this.a=a
this.$ti=b},
bJ:function bJ(a){this.a=a},
fF:function fF(){},
n:function n(){},
q:function q(){},
bg:function bg(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bh:function bh(a,b,c){this.a=a
this.b=b
this.$ti=c},
ca:function ca(a,b,c){this.a=a
this.b=b
this.$ti=c},
cp:function cp(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
I:function I(a,b,c){this.a=a
this.b=b
this.$ti=c},
aa:function aa(a,b,c){this.a=a
this.b=b
this.$ti=c},
Z:function Z(a,b,c){this.a=a
this.b=b
this.$ti=c},
b6:function b6(a,b,c){this.a=a
this.b=b
this.$ti=c},
cc:function cc(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cb:function cb(a){this.$ti=a},
a6:function a6(){},
aP:function aP(a,b){this.a=a
this.$ti=b},
cX:function cX(){},
ho(a,b,c){var t,s,r,q,p,o,n,m=A.k(a),l=A.eV(new A.ao(a,m.i("ao<1>")),!0,b),k=l.length,j=0
for(;;){if(!(j<k)){t=!0
break}s=l[j]
if(typeof s!="string"||"__proto__"===s){t=!1
break}++j}if(t){r={}
for(q=0,j=0;j<l.length;l.length===k||(0,A.v)(l),++j,q=p){s=l[j]
c.a(a.h(0,s))
p=q+1
r[s]=q}o=A.eV(new A.bf(a,m.i("bf<2>")),!0,c)
n=new A.t(r,o,b.i("@<0>").u(c).i("t<1,2>"))
n.$keys=l
return n}return new A.c7(A.jU(a,b,c),b.i("@<0>").u(c).i("c7<1,2>"))},
jE(){throw A.a(A.cG("Cannot modify constant Set"))},
j7(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
lD(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.eA.b(a)},
A(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.b1(a)
return t},
dJ(a){var t,s=$.ii
if(s==null)s=$.ii=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
k2(a,b){var t,s=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(s==null)return null
if(3>=s.length)return A.b(s,3)
t=s[3]
if(t!=null)return parseInt(a,10)
if(s[2]!=null)return parseInt(a,16)
return null},
dK(a){var t,s,r,q
if(a instanceof A.e)return A.af(A.b0(a),null)
t=J.bx(a)
if(t===B.aV||t===B.aX||u.ak.b(a)){s=B.z(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.af(A.b0(a),null)},
k3(a){var t,s,r
if(typeof a=="number"||A.hP(a))return J.b1(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.aK)return a.m(0)
t=$.jo()
for(s=0;s<1;++s){r=t[s].cK(a)
if(r!=null)return r}return"Instance of '"+A.dK(a)+"'"},
ih(a){var t,s,r,q,p=a.length
if(p<=500)return String.fromCharCode.apply(null,a)
for(t="",s=0;s<p;s=r){r=s+500
q=r<p?r:p
t+=String.fromCharCode.apply(null,a.slice(s,q))}return t},
k5(a){var t,s,r,q=A.j([],u.t)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.v)(a),++s){r=a[s]
if(!A.a2(r))throw A.a(A.c_(r))
if(r<=65535)B.a.q(q,r)
else if(r<=1114111){B.a.q(q,55296+(B.b.a4(r-65536,10)&1023))
B.a.q(q,56320+(r&1023))}else throw A.a(A.c_(r))}return A.ih(q)},
k4(a){var t,s,r
for(t=a.length,s=0;s<t;++s){r=a[s]
if(!A.a2(r))throw A.a(A.c_(r))
if(r<0)throw A.a(A.c_(r))
if(r>65535)return A.k5(a)}return A.ih(a)},
Y(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.b.a4(t,10)|55296)>>>0,t&1023|56320)}throw A.a(A.ap(a,0,1114111,null,null))},
io(a,b,c,d,e,f,g,h,i){var t,s,r,q=b-1
if(0<=a&&a<100){a+=400
q-=4800}t=B.b.O(h,1000)
g+=B.b.A(h-t,1000)
s=i?Date.UTC(a,q,c,d,e,f,g):new Date(a,q,c,d,e,f,g).valueOf()
r=!0
if(!isNaN(s))if(!(s<-864e13))if(!(s>864e13))r=s===864e13&&t!==0
if(r)return null
return s},
a8(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
bj(a){return a.c?A.a8(a).getUTCFullYear()+0:A.a8(a).getFullYear()+0},
dI(a){return a.c?A.a8(a).getUTCMonth()+1:A.a8(a).getMonth()+1},
dH(a){return a.c?A.a8(a).getUTCDate()+0:A.a8(a).getDate()+0},
ij(a){return a.c?A.a8(a).getUTCHours()+0:A.a8(a).getHours()+0},
il(a){return a.c?A.a8(a).getUTCMinutes()+0:A.a8(a).getMinutes()+0},
im(a){return a.c?A.a8(a).getUTCSeconds()+0:A.a8(a).getSeconds()+0},
ik(a){return a.c?A.a8(a).getUTCMilliseconds()+0:A.a8(a).getMilliseconds()+0},
k1(a){return B.b.O((a.c?A.a8(a).getUTCDay()+0:A.a8(a).getDay()+0)+6,7)+1},
ly(a){throw A.a(A.c_(a))},
b(a,b){if(a==null)J.c2(a)
throw A.a(A.ha(a,b))},
ha(a,b){var t,s="index"
if(!A.a2(b))return new A.at(!0,b,s,null)
t=J.c2(a)
if(b<0||b>=t)return A.hq(b,t,a,s)
return A.k6(b,s)},
lq(a,b,c){if(a>c)return A.ap(a,0,c,"start",null)
if(b!=null)if(b<a||b>c)return A.ap(b,a,c,"end",null)
return new A.at(!0,b,"end",null)},
c_(a){return new A.at(!0,a,null,null)},
a(a){return A.a_(a,new Error())},
a_(a,b){var t
if(a==null)a=new A.cC()
b.dartException=a
t=A.lL
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
lL(){return J.b1(this.dartException)},
i(a,b){throw A.a_(a,b==null?new Error():b)},
J(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.i(A.kO(a,b,c),t)},
kO(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.cF("'"+t+"': Cannot "+p+" "+m+l+o)},
v(a){throw A.a(A.V(a))},
aI(a){var t,s,r,q,p,o
a=A.lI(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.j([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.fI(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
fJ(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
iv(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
hu(a,b){var t=b==null,s=t?null:b.method
return new A.dq(a,s,t?null:b.receiver)},
hl(a){if(a==null)return new A.fx(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.bz(a,a.dartException)
return A.lk(a)},
bz(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
lk(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.b.a4(s,16)&8191)===10)switch(r){case 438:return A.bz(a,A.hu(A.A(t)+" (Error "+r+")",null))
case 445:case 5007:A.A(t)
return A.bz(a,new A.cw())}}if(a instanceof TypeError){q=$.ja()
p=$.jb()
o=$.jc()
n=$.jd()
m=$.jg()
l=$.jh()
k=$.jf()
$.je()
j=$.jj()
i=$.ji()
h=q.U(t)
if(h!=null)return A.bz(a,A.hu(A.u(t),h))
else{h=p.U(t)
if(h!=null){h.method="call"
return A.bz(a,A.hu(A.u(t),h))}else if(o.U(t)!=null||n.U(t)!=null||m.U(t)!=null||l.U(t)!=null||k.U(t)!=null||n.U(t)!=null||j.U(t)!=null||i.U(t)!=null){A.u(t)
return A.bz(a,new A.cw())}}return A.bz(a,new A.dV(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.cB()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.bz(a,new A.at(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.cB()
return a},
j4(a){if(a==null)return J.e9(a)
if(typeof a=="object")return A.dJ(a)
return J.e9(a)},
ls(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.l(0,a[t],a[s])}return b},
lt(a,b){var t,s=a.length
for(t=0;t<s;++t)b.q(0,a[t])
return b},
kX(a,b,c,d,e,f){u.Z.a(a)
switch(A.E(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.a(new A.fP("Unsupported number of arguments for wrapped closure"))},
lm(a,b){var t=a.$identity
if(!!t)return t
t=A.ln(a,b)
a.$identity=t
return t},
ln(a,b){var t
switch(b){case 0:t=a.$0
break
case 1:t=a.$1
break
case 2:t=a.$2
break
case 3:t=a.$3
break
case 4:t=a.$4
break
default:t=null}if(t!=null)return t.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.kX)},
jD(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.dQ().constructor.prototype):Object.create(new A.bC(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.i4(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.jz(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.i4(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
jz(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.a("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.jw)}throw A.a("Error in functionType of tearoff")},
jA(a,b,c,d){var t=A.i2
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
i4(a,b,c,d){if(c)return A.jC(a,b,d)
return A.jA(b.length,d,a,b)},
jB(a,b,c,d){var t=A.i2,s=A.jx
switch(b?-1:a){case 0:throw A.a(new A.dM("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
jC(a,b,c){var t,s
if($.i0==null)$.i0=A.i_("interceptor")
if($.i1==null)$.i1=A.i_("receiver")
t=b.length
s=A.jB(t,c,a,b)
return s},
hR(a){return A.jD(a)},
jw(a,b){return A.fY(v.typeUniverse,A.b0(a.a),b)},
i2(a){return a.a},
jx(a){return a.b},
i_(a){var t,s,r,q=new A.bC("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.a(A.bB("Field name "+a+" not found."))},
j2(a){return v.getIsolateTag(a)},
mc(a,b,c){Object.defineProperty(a,b,{value:c,enumerable:false,writable:true,configurable:true})},
lF(a){var t,s,r,q,p,o=A.u($.j3.$1(a)),n=$.hb[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.hh[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.aW($.j0.$2(a,o))
if(r!=null){n=$.hb[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.hh[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.hk(t)
$.hb[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.hh[o]=t
return t}if(q==="-"){p=A.hk(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.j5(a,t)
if(q==="*")throw A.a(A.iw(o))
if(v.leafTags[o]===true){p=A.hk(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.j5(a,t)},
j5(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.hU(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
hk(a){return J.hU(a,!1,null,!!a.$iae)},
lH(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.hk(t)
else return J.hU(t,c,null,null)},
lA(){if(!0===$.hS)return
$.hS=!0
A.lB()},
lB(){var t,s,r,q,p,o,n,m
$.hb=Object.create(null)
$.hh=Object.create(null)
A.lz()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.j6.$1(p)
if(o!=null){n=A.lH(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
lz(){var t,s,r,q,p,o,n=B.T()
n=A.bZ(B.U,A.bZ(B.V,A.bZ(B.A,A.bZ(B.A,A.bZ(B.W,A.bZ(B.X,A.bZ(B.Y(B.z),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.j3=new A.he(q)
$.j0=new A.hf(p)
$.j6=new A.hg(o)},
bZ(a,b){return a(b)||b},
lp(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
jT(a,b,c,d,e,f){var t=b?"m":"",s=c?"":"i",r=d?"u":"",q=e?"s":"",p=function(g,h){try{return new RegExp(g,h)}catch(o){return o}}(a,t+s+r+q+f)
if(p instanceof RegExp)return p
throw A.a(A.f("Illegal RegExp pattern ("+String(p)+")",a))},
lJ(a,b,c){var t=a.indexOf(b,c)
return t>=0},
lI(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
c7:function c7(a,b){this.a=a
this.$ti=b},
c6:function c6(){},
t:function t(a,b,c){this.a=a
this.b=b
this.$ti=c},
cK:function cK(a,b){this.a=a
this.$ti=b},
br:function br(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
c8:function c8(){},
w:function w(a,b,c){this.a=a
this.b=b
this.$ti=c},
cA:function cA(){},
fI:function fI(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
cw:function cw(){},
dq:function dq(a,b,c){this.a=a
this.b=b
this.c=c},
dV:function dV(a){this.a=a},
fx:function fx(a){this.a=a},
aK:function aK(){},
d5:function d5(){},
d6:function d6(){},
dR:function dR(){},
dQ:function dQ(){},
bC:function bC(a,b){this.a=a
this.b=b},
dM:function dM(a){this.a=a},
aG:function aG(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
eP:function eP(a){this.a=a},
eS:function eS(a,b){this.a=a
this.b=b
this.c=null},
ao:function ao(a,b){this.a=a
this.$ti=b},
be:function be(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bf:function bf(a,b){this.a=a
this.$ti=b},
cn:function cn(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
a7:function a7(a,b){this.a=a
this.$ti=b},
cm:function cm(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
he:function he(a){this.a=a},
hf:function hf(a){this.a=a},
hg:function hg(a){this.a=a},
dp:function dp(a,b){this.a=a
this.b=b
this.c=null},
fV:function fV(a){this.b=a},
lK(a){throw A.a_(new A.bJ("Field '"+a+"' has been assigned during initialization."),new Error())},
dZ(a){var t=new A.fO(a)
return t.b=t},
fO:function fO(a){this.a=a
this.b=null},
jZ(a,b,c){var t=new DataView(a,b)
return t},
k_(a){return new Uint8Array(a)},
bu(a,b,c){if(a>>>0!==a||a>=c)throw A.a(A.ha(b,a))},
kM(a,b,c){var t
if(!(a>>>0!==a))t=b>>>0!==b||a>b||b>c
else t=!0
if(t)throw A.a(A.lq(a,b,c))
return b},
bi:function bi(){},
cs:function cs(){},
fZ:function fZ(a){this.a=a},
dv:function dv(){},
bL:function bL(){},
cq:function cq(){},
cr:function cr(){},
dw:function dw(){},
dx:function dx(){},
dy:function dy(){},
dz:function dz(){},
dA:function dA(){},
dB:function dB(){},
dC:function dC(){},
ct:function ct(){},
cu:function cu(){},
cL:function cL(){},
cM:function cM(){},
cN:function cN(){},
cO:function cO(){},
hx(a,b){var t=b.c
return t==null?b.c=A.cU(a,"i8",[b.x]):t},
ir(a){var t=a.w
if(t===6||t===7)return A.ir(a.x)
return t===11||t===12},
k8(a){return a.as},
ak(a){return A.fX(v.typeUniverse,a,!1)},
bv(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.bv(a0,t,a2,a3)
if(s===t)return a1
return A.iO(a0,s,!0)
case 7:t=a1.x
s=A.bv(a0,t,a2,a3)
if(s===t)return a1
return A.iN(a0,s,!0)
case 8:r=a1.y
q=A.bY(a0,r,a2,a3)
if(q===r)return a1
return A.cU(a0,a1.x,q)
case 9:p=a1.x
o=A.bv(a0,p,a2,a3)
n=a1.y
m=A.bY(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.hH(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.bY(a0,k,a2,a3)
if(j===k)return a1
return A.iP(a0,l,j)
case 11:i=a1.x
h=A.bv(a0,i,a2,a3)
g=a1.y
f=A.lh(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.iM(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.bY(a0,e,a2,a3)
p=a1.x
o=A.bv(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.hI(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.a(A.d1("Attempted to substitute unexpected RTI kind "+a))}},
bY(a,b,c,d){var t,s,r,q,p=b.length,o=A.h0(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.bv(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
li(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.h0(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.bv(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
lh(a,b,c,d){var t,s=b.a,r=A.bY(a,s,c,d),q=b.b,p=A.bY(a,q,c,d),o=b.c,n=A.li(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.e2()
t.a=r
t.b=p
t.c=n
return t},
j(a,b){a[v.arrayRti]=b
return a},
j1(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.lx(t)
return a.$S()}return null},
lC(a,b){var t
if(A.ir(b))if(a instanceof A.aK){t=A.j1(a)
if(t!=null)return t}return A.b0(a)},
b0(a){if(a instanceof A.e)return A.k(a)
if(Array.isArray(a))return A.y(a)
return A.hN(J.bx(a))},
y(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
k(a){var t=a.$ti
return t!=null?t:A.hN(a)},
hN(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.kV(a,t)},
kV(a,b){var t=a instanceof A.aK?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.kE(v.typeUniverse,t.name)
b.$ccache=s
return s},
lx(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.fX(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
lw(a){return A.bw(A.k(a))},
lg(a){var t=a instanceof A.aK?A.j1(a):null
if(t!=null)return t
if(u.ci.b(a))return J.jv(a).a
if(Array.isArray(a))return A.y(a)
return A.b0(a)},
bw(a){var t=a.r
return t==null?a.r=new A.fW(a):t},
as(a){return A.bw(A.fX(v.typeUniverse,a,!1))},
kU(a){var t=this
t.b=A.lf(t)
return t.b(a)},
lf(a){var t,s,r,q,p
if(a===u.K)return A.l2
if(A.by(a))return A.l6
t=a.w
if(t===6)return A.kS
if(t===1)return A.iY
if(t===7)return A.kY
s=A.le(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.by)){a.f="$i"+r
if(r==="p")return A.l0
if(a===u.o)return A.l_
return A.l5}}else if(t===10){q=A.lp(a.x,a.y)
p=q==null?A.iY:q
return p==null?A.hL(p):p}return A.kQ},
le(a){if(a.w===8){if(a===u.S)return A.a2
if(a===u.i||a===u.H)return A.l1
if(a===u.N)return A.l4
if(a===u.y)return A.hP}return null},
kT(a){var t=this,s=A.kP
if(A.by(t))s=A.kJ
else if(t===u.K)s=A.hL
else if(A.c0(t)){s=A.kR
if(t===u.h6)s=A.kH
else if(t===u.dk)s=A.aW
else if(t===u.fQ)s=A.iS
else if(t===u.cg)s=A.e6
else if(t===u.cD)s=A.kG
else if(t===u.bX)s=A.kI}else if(t===u.S)s=A.E
else if(t===u.N)s=A.u
else if(t===u.y)s=A.h1
else if(t===u.H)s=A.hK
else if(t===u.i)s=A.hJ
else if(t===u.o)s=A.cY
t.a=s
return t.a(a)},
kQ(a){var t=this
if(a==null)return A.c0(t)
return A.lE(v.typeUniverse,A.lC(a,t),t)},
kS(a){if(a==null)return!0
return this.x.b(a)},
l5(a){var t,s=this
if(a==null)return A.c0(s)
t=s.f
if(a instanceof A.e)return!!a[t]
return!!J.bx(a)[t]},
l0(a){var t,s=this
if(a==null)return A.c0(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.e)return!!a[t]
return!!J.bx(a)[t]},
l_(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.e)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
iX(a){if(typeof a=="object"){if(a instanceof A.e)return u.o.b(a)
return!0}if(typeof a=="function")return!0
return!1},
kP(a){var t=this
if(a==null){if(A.c0(t))return a}else if(t.b(a))return a
throw A.a_(A.iT(a,t),new Error())},
kR(a){var t=this
if(a==null||t.b(a))return a
throw A.a_(A.iT(a,t),new Error())},
iT(a,b){return new A.cS("TypeError: "+A.iF(a,A.af(b,null)))},
iF(a,b){return A.dc(a)+": type '"+A.af(A.lg(a),null)+"' is not a subtype of type '"+b+"'"},
aj(a,b){return new A.cS("TypeError: "+A.iF(a,b))},
kY(a){var t=this
return t.x.b(a)||A.hx(v.typeUniverse,t).b(a)},
l2(a){return a!=null},
hL(a){if(a!=null)return a
throw A.a_(A.aj(a,"Object"),new Error())},
l6(a){return!0},
kJ(a){return a},
iY(a){return!1},
hP(a){return!0===a||!1===a},
h1(a){if(!0===a)return!0
if(!1===a)return!1
throw A.a_(A.aj(a,"bool"),new Error())},
iS(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.a_(A.aj(a,"bool?"),new Error())},
hJ(a){if(typeof a=="number")return a
throw A.a_(A.aj(a,"double"),new Error())},
kG(a){if(typeof a=="number")return a
if(a==null)return a
throw A.a_(A.aj(a,"double?"),new Error())},
a2(a){return typeof a=="number"&&Math.floor(a)===a},
E(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.a_(A.aj(a,"int"),new Error())},
kH(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.a_(A.aj(a,"int?"),new Error())},
l1(a){return typeof a=="number"},
hK(a){if(typeof a=="number")return a
throw A.a_(A.aj(a,"num"),new Error())},
e6(a){if(typeof a=="number")return a
if(a==null)return a
throw A.a_(A.aj(a,"num?"),new Error())},
l4(a){return typeof a=="string"},
u(a){if(typeof a=="string")return a
throw A.a_(A.aj(a,"String"),new Error())},
aW(a){if(typeof a=="string")return a
if(a==null)return a
throw A.a_(A.aj(a,"String?"),new Error())},
cY(a){if(A.iX(a))return a
throw A.a_(A.aj(a,"JSObject"),new Error())},
kI(a){if(a==null)return a
if(A.iX(a))return a
throw A.a_(A.aj(a,"JSObject?"),new Error())},
iZ(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.af(a[r],b)
return t},
lc(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.iZ(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.af(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
iU(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.j([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.q(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.b(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.af(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.af(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.af(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.af(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.af(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
af(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.af(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.af(a.x,b)+">"
if(m===8){q=A.lj(a.x)
p=a.y
return p.length>0?q+("<"+A.iZ(p,b)+">"):q}if(m===10)return A.lc(a,b)
if(m===11)return A.iU(a,b,null)
if(m===12)return A.iU(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.b(b,o)
return b[o]}return"?"},
lj(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
kF(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
kE(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.fX(a,b,!1)
else if(typeof n=="number"){t=n
s=A.cV(a,5,"#")
r=A.h0(t)
for(q=0;q<t;++q)r[q]=s
p=A.cU(a,b,r)
o[b]=p
return p}else return n},
kC(a,b){return A.iQ(a.tR,b)},
kB(a,b){return A.iQ(a.eT,b)},
fX(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.iJ(A.iH(a,null,b,!1))
s.set(b,t)
return t},
fY(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.iJ(A.iH(a,b,c,!0))
r.set(c,s)
return s},
kD(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.hH(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
aV(a,b){b.a=A.kT
b.b=A.kU
return b},
cV(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.aq(null,null)
t.w=b
t.as=c
s=A.aV(a,t)
a.eC.set(c,s)
return s},
iO(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.kz(a,b,s,c)
a.eC.set(s,t)
return t},
kz(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.by(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.c0(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.aq(null,null)
r.w=6
r.x=b
r.as=c
return A.aV(a,r)},
iN(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.kx(a,b,s,c)
a.eC.set(s,t)
return t},
kx(a,b,c,d){var t,s
if(d){t=b.w
if(A.by(b)||b===u.K)return b
else if(t===1)return A.cU(a,"i8",[b])
else if(b===u.P||b===u.T)return u.eH}s=new A.aq(null,null)
s.w=7
s.x=b
s.as=c
return A.aV(a,s)},
kA(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.aq(null,null)
t.w=13
t.x=b
t.as=r
s=A.aV(a,t)
a.eC.set(r,s)
return s},
cT(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
kw(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
cU(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.cT(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.aq(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.aV(a,s)
a.eC.set(q,r)
return r},
hH(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.cT(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.aq(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.aV(a,p)
a.eC.set(r,o)
return o},
iP(a,b,c){var t,s,r="+"+(b+"("+A.cT(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.aq(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.aV(a,t)
a.eC.set(r,s)
return s},
iM(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.cT(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.cT(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.kw(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.aq(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.aV(a,q)
a.eC.set(s,p)
return p},
hI(a,b,c,d){var t,s=b.as+("<"+A.cT(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.ky(a,b,c,s,d)
a.eC.set(s,t)
return t},
ky(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.h0(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.bv(a,b,s,0)
n=A.bY(a,c,s,0)
return A.hI(a,o,n,c!==n)}}m=new A.aq(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.aV(a,m)},
iH(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
iJ(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.kr(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.iI(a,s,m,l,!1)
else if(r===46)s=A.iI(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.bt(a.u,a.e,l.pop()))
break
case 94:l.push(A.kA(a.u,l.pop()))
break
case 35:l.push(A.cV(a.u,5,"#"))
break
case 64:l.push(A.cV(a.u,2,"@"))
break
case 126:l.push(A.cV(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.kt(a,l)
break
case 38:A.ks(a,l)
break
case 63:q=a.u
l.push(A.iO(q,A.bt(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.iN(q,A.bt(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.kq(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.iK(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.kv(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.bt(a.u,a.e,n)},
kr(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
iI(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.kF(t,p.x)[q]
if(o==null)A.i('No "'+q+'" in "'+A.k8(p)+'"')
d.push(A.fY(t,p,o))}else d.push(q)
return n},
kt(a,b){var t,s=a.u,r=A.iG(a,b),q=b.pop()
if(typeof q=="string")b.push(A.cU(s,q,r))
else{t=A.bt(s,a.e,q)
switch(t.w){case 11:b.push(A.hI(s,t,r,a.n))
break
default:b.push(A.hH(s,t,r))
break}}},
kq(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.iG(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.bt(q,a.e,p)
r=new A.e2()
r.a=t
r.b=o
r.c=n
b.push(A.iM(q,s,r))
return
case-4:b.push(A.iP(q,b.pop(),t))
return
default:throw A.a(A.d1("Unexpected state under `()`: "+A.A(p)))}},
ks(a,b){var t=b.pop()
if(0===t){b.push(A.cV(a.u,1,"0&"))
return}if(1===t){b.push(A.cV(a.u,4,"1&"))
return}throw A.a(A.d1("Unexpected extended operation "+A.A(t)))},
iG(a,b){var t=b.splice(a.p)
A.iK(a.u,a.e,t)
a.p=b.pop()
return t},
bt(a,b,c){if(typeof c=="string")return A.cU(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.ku(a,b,c)}else return c},
iK(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.bt(a,b,c[t])},
kv(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.bt(a,b,c[t])},
ku(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.a(A.d1("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.a(A.d1("Bad index "+c+" for "+b.m(0)))},
lE(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.S(a,b,null,c,null)
s.set(c,t)}return t},
S(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.by(d))return!0
t=b.w
if(t===4)return!0
if(A.by(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.S(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.S(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.S(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.S(a,b.x,c,d,e))return!1
return A.S(a,A.hx(a,b),c,d,e)}if(t===6)return A.S(a,q,c,d,e)&&A.S(a,b.x,c,d,e)
if(r===7){if(A.S(a,b,c,d.x,e))return!0
return A.S(a,b,c,A.hx(a,d),e)}if(r===6)return A.S(a,b,c,q,e)||A.S(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.gT)return!0
if(r===12){if(b===u.e)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.S(a,k,c,j,e)||!A.S(a,j,e,k,c))return!1}return A.iW(a,b.x,c,d.x,e)}if(r===11){if(b===u.e)return!0
if(q)return!1
return A.iW(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.kZ(a,b,c,d,e)}if(p&&r===10)return A.l3(a,b,c,d,e)
return!1},
iW(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.S(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.S(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.S(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.S(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.S(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
kZ(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.fY(a,b,s[p])
return A.iR(a,q,null,c,d.y,e)}return A.iR(a,b.y,null,c,d.y,e)},
iR(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.S(a,b[t],d,e[t],f))return!1
return!0},
l3(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.S(a,s[t],c,r[t],e))return!1
return!0},
c0(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.by(a))if(t!==6)s=t===7&&A.c0(a.x)
return s},
by(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
iQ(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
h0(a){return a>0?new Array(a):v.typeUniverse.sEA},
aq:function aq(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
e2:function e2(){this.c=this.b=this.a=null},
fW:function fW(a){this.a=a},
e1:function e1(){},
cS:function cS(a){this.a=a},
iL(a,b,c){return 0},
cR:function cR(a,b){var _=this
_.a=a
_.e=_.d=_.c=_.b=null
_.$ti=b},
bW:function bW(a,b){this.a=a
this.$ti=b},
ie(a,b){return new A.aG(a.i("@<0>").u(b).i("aG<1,2>"))},
G(a,b,c){return b.i("@<0>").u(c).i("id<1,2>").a(A.ls(a,new A.aG(b.i("@<0>").u(c).i("aG<1,2>"))))},
C(a,b){return new A.aG(a.i("@<0>").u(b).i("aG<1,2>"))},
hv(a){return new A.ar(a.i("ar<0>"))},
jV(a){return new A.ar(a.i("ar<0>"))},
jW(a,b){return b.i("ig<0>").a(A.lt(a,new A.ar(b.i("ar<0>"))))},
hG(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fU(a,b,c){var t=new A.bs(a,b,c.i("bs<0>"))
t.c=a.e
return t},
i9(a,b){var t=J.O(a.a)
if(new A.Z(t,a.b,a.$ti.i("Z<1>")).j())return t.gk()
return null},
jU(a,b,c){var t=A.ie(b,c)
a.T(0,new A.eT(t,b,c))
return t},
ax(a,b,c){var t=A.ie(b,c)
t.J(0,a)
return t},
eU(a,b){var t,s,r=A.hv(b)
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.v)(a),++s)r.q(0,b.a(a[s]))
return r},
dt(a,b){var t=A.hv(b)
t.J(0,a)
return t},
fv(a){var t,s
if(A.hT(a))return"{...}"
t=new A.bS("")
try{s={}
B.a.q($.ag,a)
t.a+="{"
s.a=!0
a.T(0,new A.fw(s,t))
t.a+="}"}finally{if(0>=$.ag.length)return A.b($.ag,-1)
$.ag.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
ar:function ar(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
e5:function e5(a){this.a=a
this.c=this.b=null},
bs:function bs(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
eT:function eT(a,b,c){this.a=a
this.b=b
this.c=c},
z:function z(){},
K:function K(){},
fu:function fu(a){this.a=a},
fw:function fw(a,b){this.a=a
this.b=b},
cW:function cW(){},
bK:function bK(){},
cE:function cE(){},
aQ:function aQ(){},
cQ:function cQ(){},
bX:function bX(){},
lb(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.hl(s)
r=A.f(String(t),null)
throw A.a(r)}r=A.h3(q)
return r},
h3(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.e3(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.h3(a[t])
return a},
ic(a,b,c){return new A.ck(a,b)},
kN(a){return a.t()},
ko(a,b){return new A.fR(a,[],A.lo())},
kp(a,b,c){var t,s=new A.bS(""),r=A.ko(s,b)
r.ad(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
e3:function e3(a,b){this.a=a
this.b=b
this.c=null},
e4:function e4(a){this.a=a},
d7:function d7(){},
d9:function d9(){},
ck:function ck(a,b){this.a=a
this.b=b},
ds:function ds(a,b){this.a=a
this.b=b},
dr:function dr(){},
eR:function eR(a){this.b=a},
eQ:function eQ(a){this.a=a},
fS:function fS(){},
fT:function fT(a,b){this.a=a
this.b=b},
fR:function fR(a,b,c){this.c=a
this.a=b
this.b=c},
fK:function fK(){},
h_:function h_(a){this.b=0
this.c=a},
iE(a,b){var t=A.kn(a,b)
if(t==null)throw A.a(A.f("Could not parse BigInt",a))
return t},
kj(a,b){var t,s,r=$.ac(),q=a.length,p=4-q%4
if(p===4)p=0
for(t=0,s=0;s<q;++s){t=t*10+a.charCodeAt(s)-48;++p
if(p===4){r=r.a3(0,$.hV()).aS(0,A.aT(t))
t=0
p=0}}if(b)return r.L(0)
return r},
hE(a){if(48<=a&&a<=57)return a-48
return(a|32)-97+10},
kk(a,b,c){var t,s,r,q,p,o,n,m=a.length,l=m-b,k=B.q.cb(l/4),j=new Uint16Array(k),i=k-1,h=l-i*4
for(t=b,s=0,r=0;r<h;++r,t=q){q=t+1
if(!(t<m))return A.b(a,t)
p=A.hE(a.charCodeAt(t))
if(p>=16)return null
s=s*16+p}o=i-1
if(!(i>=0&&i<k))return A.b(j,i)
j[i]=s
for(;t<m;o=n){for(s=0,r=0;r<4;++r,t=q){q=t+1
if(!(t>=0&&t<m))return A.b(a,t)
p=A.hE(a.charCodeAt(t))
if(p>=16)return null
s=s*16+p}n=o-1
if(!(o>=0&&o<k))return A.b(j,o)
j[o]=s}if(k===1){if(0>=k)return A.b(j,0)
m=j[0]===0}else m=!1
if(m)return $.ac()
m=A.X(k,j)
return new A.L(m===0?!1:c,j,m)},
kl(a,b,c){var t,s,r,q=$.ac(),p=A.aT(b)
for(t=a.length,s=0;s<t;++s){r=A.hE(a.charCodeAt(s))
if(r>=b)return null
q=q.a3(0,p).aS(0,A.aT(r))}if(c)return q.L(0)
return q},
kn(a,b){var t,s,r,q,p,o,n,m=null
if(a==="")return m
t=$.jl().bj(a)
if(t==null)return m
s=t.b
r=s.length
if(1>=r)return A.b(s,1)
q=s[1]==="-"
if(4>=r)return A.b(s,4)
p=s[4]
o=s[3]
if(5>=r)return A.b(s,5)
n=s[5]
if(b<2||b>36)throw A.a(A.ap(b,2,36,"radix",m))
if(b===10&&p!=null)return A.kj(p,q)
if(b===16)s=p!=null||n!=null
else s=!1
if(s){if(p==null){n.toString
s=n}else s=p
return A.kk(s,0,q)}s=p==null?n:p
if(s==null){o.toString
s=o}return A.kl(s,b,q)},
X(a,b){var t,s=b.length
for(;;){if(a>0){t=a-1
if(!(t<s))return A.b(b,t)
t=b[t]===0}else t=!1
if(!t)break;--a}return a},
hD(a,b,c,d){var t,s,r,q=new Uint16Array(d),p=c-b
for(t=a.length,s=0;s<p;++s){r=b+s
if(!(r>=0&&r<t))return A.b(a,r)
r=a[r]
if(!(s<d))return A.b(q,s)
q[s]=r}return q},
kg(a){var t
if(a===0)return $.ac()
if(a===1)return $.aA()
if(a===2)return $.jm()
if(Math.abs(a)<4294967296)return A.aT(B.b.aO(a))
t=A.kf(a)
return t},
aT(a){var t,s,r,q,p=a<0
if(p){if(a===-9223372036854776e3){t=new Uint16Array(4)
t[3]=32768
s=A.X(4,t)
return new A.L(s!==0,t,s)}a=-a}if(a<65536){t=new Uint16Array(1)
t[0]=a
s=A.X(1,t)
return new A.L(s===0?!1:p,t,s)}if(a<=4294967295){t=new Uint16Array(2)
t[0]=a&65535
t[1]=B.b.a4(a,16)
s=A.X(2,t)
return new A.L(s===0?!1:p,t,s)}s=B.b.A(B.b.gbg(a)-1,16)+1
t=new Uint16Array(s)
for(r=0;a!==0;r=q){q=r+1
if(!(r<s))return A.b(t,r)
t[r]=a&65535
a=B.b.A(a,65536)}s=A.X(s,t)
return new A.L(s===0?!1:p,t,s)},
kf(a){var t,s,r,q,p,o,n,m
if(isNaN(a)||a==1/0||a==-1/0)throw A.a(A.bB("Value must be finite: "+a))
t=a<0
if(t)a=-a
a=Math.floor(a)
if(a===0)return $.ac()
s=$.jk()
for(r=s.$flags|0,q=0;q<8;++q){r&2&&A.J(s)
if(!(q<8))return A.b(s,q)
s[q]=0}r=J.jr(B.bI.gca(s))
r.$flags&2&&A.J(r,13)
r.setFloat64(0,a,!0)
p=(s[7]<<4>>>0)+(s[6]>>>4)-1075
o=new Uint16Array(4)
o[0]=(s[1]<<8>>>0)+s[0]
o[1]=(s[3]<<8>>>0)+s[2]
o[2]=(s[5]<<8>>>0)+s[4]
o[3]=s[6]&15|16
n=new A.L(!1,o,4)
if(p<0)m=n.aT(0,-p)
else m=p>0?n.X(0,p):n
if(t)return m.L(0)
return m},
hF(a,b,c,d){var t,s,r,q,p
if(b===0)return 0
if(c===0&&d===a)return b
for(t=b-1,s=a.length,r=d.$flags|0;t>=0;--t){q=t+c
if(!(t<s))return A.b(a,t)
p=a[t]
r&2&&A.J(d)
if(!(q>=0&&q<d.length))return A.b(d,q)
d[q]=p}for(t=c-1;t>=0;--t){r&2&&A.J(d)
if(!(t<d.length))return A.b(d,t)
d[t]=0}return b+c},
iC(a,b,c,d){var t,s,r,q,p,o,n,m=B.b.A(c,16),l=B.b.O(c,16),k=16-l,j=B.b.X(1,k)-1
for(t=b-1,s=a.length,r=d.$flags|0,q=0;t>=0;--t){if(!(t<s))return A.b(a,t)
p=a[t]
o=t+m+1
n=B.b.aA(p,k)
r&2&&A.J(d)
if(!(o>=0&&o<d.length))return A.b(d,o)
d[o]=(n|q)>>>0
q=B.b.X(p&j,l)}r&2&&A.J(d)
if(!(m>=0&&m<d.length))return A.b(d,m)
d[m]=q},
ix(a,b,c,d){var t,s,r,q=B.b.A(c,16)
if(B.b.O(c,16)===0)return A.hF(a,b,q,d)
t=b+q+1
A.iC(a,b,c,d)
for(s=d.$flags|0,r=q;--r,r>=0;){s&2&&A.J(d)
if(!(r<d.length))return A.b(d,r)
d[r]=0}s=t-1
if(!(s>=0&&s<d.length))return A.b(d,s)
if(d[s]===0)t=s
return t},
km(a,b,c,d){var t,s,r,q,p,o,n=B.b.A(c,16),m=B.b.O(c,16),l=16-m,k=B.b.X(1,m)-1,j=a.length
if(!(n>=0&&n<j))return A.b(a,n)
t=B.b.aA(a[n],m)
s=b-n-1
for(r=d.$flags|0,q=0;q<s;++q){p=q+n+1
if(!(p<j))return A.b(a,p)
o=a[p]
p=B.b.X(o&k,l)
r&2&&A.J(d)
if(!(q<d.length))return A.b(d,q)
d[q]=(p|t)>>>0
t=B.b.aA(o,m)}r&2&&A.J(d)
if(!(s>=0&&s<d.length))return A.b(d,s)
d[s]=t},
fL(a,b,c,d){var t,s,r,q,p=b-d
if(p===0)for(t=b-1,s=a.length,r=c.length;t>=0;--t){if(!(t<s))return A.b(a,t)
q=a[t]
if(!(t<r))return A.b(c,t)
p=q-c[t]
if(p!==0)return p}return p},
kh(a,b,c,d,e){var t,s,r,q,p,o
for(t=a.length,s=c.length,r=e.$flags|0,q=0,p=0;p<d;++p){if(!(p<t))return A.b(a,p)
o=a[p]
if(!(p<s))return A.b(c,p)
q+=o+c[p]
r&2&&A.J(e)
if(!(p<e.length))return A.b(e,p)
e[p]=q&65535
q=q>>>16}for(p=d;p<b;++p){if(!(p>=0&&p<t))return A.b(a,p)
q+=a[p]
r&2&&A.J(e)
if(!(p<e.length))return A.b(e,p)
e[p]=q&65535
q=q>>>16}r&2&&A.J(e)
if(!(b>=0&&b<e.length))return A.b(e,b)
e[b]=q},
dX(a,b,c,d,e){var t,s,r,q,p,o
for(t=a.length,s=c.length,r=e.$flags|0,q=0,p=0;p<d;++p){if(!(p<t))return A.b(a,p)
o=a[p]
if(!(p<s))return A.b(c,p)
q+=o-c[p]
r&2&&A.J(e)
if(!(p<e.length))return A.b(e,p)
e[p]=q&65535
q=0-(B.b.a4(q,16)&1)}for(p=d;p<b;++p){if(!(p>=0&&p<t))return A.b(a,p)
q+=a[p]
r&2&&A.J(e)
if(!(p<e.length))return A.b(e,p)
e[p]=q&65535
q=0-(B.b.a4(q,16)&1)}},
iD(a,b,c,d,e,f){var t,s,r,q,p,o,n,m,l
if(a===0)return
for(t=b.length,s=d.length,r=d.$flags|0,q=0;--f,f>=0;e=m,c=p){p=c+1
if(!(c<t))return A.b(b,c)
o=b[c]
if(!(e>=0&&e<s))return A.b(d,e)
n=a*o+d[e]+q
m=e+1
r&2&&A.J(d)
d[e]=n&65535
q=B.b.A(n,65536)}for(;q!==0;e=m){if(!(e>=0&&e<s))return A.b(d,e)
l=d[e]+q
m=e+1
r&2&&A.J(d)
d[e]=l&65535
q=B.b.A(l,65536)}},
ki(a,b,c){var t,s,r,q=b.length
if(!(c>=0&&c<q))return A.b(b,c)
t=b[c]
if(t===a)return 65535
s=c-1
if(!(s>=0&&s<q))return A.b(b,s)
r=B.b.aV((t<<16|b[s])>>>0,a)
if(r>65535)return 65535
return r},
e8(a){var t=A.k2(a,null)
if(t!=null)return t
throw A.a(A.f(a,null))},
jX(a,b,c,d){var t,s=J.jO(a,d)
if(a!==0&&b!=null)for(t=0;t<a;++t)s[t]=b
return s},
eV(a,b,c){var t,s=A.j([],c.i("l<0>"))
for(t=J.O(a);t.j();)B.a.q(s,c.a(t.gk()))
if(b)return s
s.$flags=1
return s},
D(a,b){var t,s
if(Array.isArray(a))return A.j(a.slice(0),b.i("l<0>"))
t=A.j([],b.i("l<0>"))
for(s=J.O(a);s.j();)B.a.q(t,s.gk())
return t},
eW(a,b){var t=A.eV(a,!1,b)
t.$flags=3
return t},
it(a){var t
A.hw(0,"start")
t=A.D(a,u.S)
return A.k4(t)},
iq(a,b){return new A.dp(a,A.jT(a,!1,b,!1,!1,""))},
is(a,b,c){var t=J.O(b)
if(!t.j())return a
if(c.length===0){do a+=A.A(t.gk())
while(t.j())}else{a+=A.A(t.gk())
while(t.j())a=a+c+A.A(t.gk())}return a},
jG(a,b,c,d,e,f,g,h,i){var t=A.io(a,b,c,d,e,f,g,h,i)
if(t==null)return null
return new A.aD(A.i6(t,h,i),h,i)},
hp(a,b,c){var t=A.io(a,b,c,0,0,0,0,0,!1)
return new A.aD(t==null?new A.ew(a,b,c,0,0,0,0,0).$0():t,0,!1)},
i7(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=$.j9().bj(a)
if(d!=null){t=new A.ey()
s=d.b
if(1>=s.length)return A.b(s,1)
r=s[1]
r.toString
q=A.e8(r)
if(2>=s.length)return A.b(s,2)
r=s[2]
r.toString
p=A.e8(r)
if(3>=s.length)return A.b(s,3)
r=s[3]
r.toString
o=A.e8(r)
if(4>=s.length)return A.b(s,4)
n=t.$1(s[4])
if(5>=s.length)return A.b(s,5)
m=t.$1(s[5])
if(6>=s.length)return A.b(s,6)
l=t.$1(s[6])
if(7>=s.length)return A.b(s,7)
k=new A.ez().$1(s[7])
j=B.b.A(k,1000)
r=s.length
if(8>=r)return A.b(s,8)
i=s[8]!=null
if(i){if(9>=r)return A.b(s,9)
h=s[9]
if(h!=null){g=h==="-"?-1:1
if(10>=r)return A.b(s,10)
r=s[10]
r.toString
f=A.e8(r)
if(11>=s.length)return A.b(s,11)
m-=g*(t.$1(s[11])+60*f)}}e=A.jG(q,p,o,n,m,l,j,k%1000,i)
if(e==null)throw A.a(A.f("Time out of range",a))
return e}else throw A.a(A.f("Invalid date format",a))},
i6(a,b,c){var t="microsecond"
if(b<0||b>999)throw A.a(A.ap(b,0,999,t,null))
if(a<-864e13||a>864e13)throw A.a(A.ap(a,-864e13,864e13,"millisecondsSinceEpoch",null))
if(a===864e13&&b!==0)throw A.a(A.hY(b,t,"Time including microseconds is outside valid range"))
A.ll(c,"isUtc",u.y)
return a},
i5(a){var t=Math.abs(a),s=a<0?"-":""
if(t>=1000)return""+a
if(t>=100)return s+"0"+t
if(t>=10)return s+"00"+t
return s+"000"+t},
jH(a){var t=Math.abs(a),s=a<0?"-":"+"
if(t>=1e5)return s+t
return s+"0"+t},
ex(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
aE(a){if(a>=10)return""+a
return"0"+a},
av(a,b,c){var t,s,r
for(t=a.length,s=0;s<t;++s){r=a[s]
if(r.b===b)return r}throw A.a(A.hY(b,"name","No enum value with that name"))},
dc(a){if(typeof a=="number"||A.hP(a)||a==null)return J.b1(a)
if(typeof a=="string")return JSON.stringify(a)
return A.k3(a)},
d1(a){return new A.d0(a)},
bB(a){return new A.at(!1,null,null,a)},
hY(a,b,c){return new A.at(!0,a,b,c)},
k6(a,b){return new A.cx(null,null,!0,a,b,"Value not in range")},
ap(a,b,c,d,e){return new A.cx(b,c,!0,a,d,"Invalid value")},
ip(a,b,c){if(0>a||a>c)throw A.a(A.ap(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.a(A.ap(b,a,c,"end",null))
return b}return c},
hw(a,b){if(a<0)throw A.a(A.ap(a,0,null,b,null))
return a},
hq(a,b,c,d){return new A.di(b,!0,a,d,"Index out of range")},
cG(a){return new A.cF(a)},
iw(a){return new A.dU(a)},
dP(a){return new A.bR(a)},
V(a){return new A.d8(a)},
f(a,b){return new A.ai(a,b)},
jN(a,b,c){var t,s
if(A.hT(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.j([],u.s)
B.a.q($.ag,a)
try{A.l7(a,t)}finally{if(0>=$.ag.length)return A.b($.ag,-1)
$.ag.pop()}s=A.is(b,u.hf.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
hs(a,b,c){var t,s
if(A.hT(a))return b+"..."+c
t=new A.bS(b)
B.a.q($.ag,a)
try{s=t
s.a=A.is(s.a,a,", ")}finally{if(0>=$.ag.length)return A.b($.ag,-1)
$.ag.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
l7(a,b){var t,s,r,q,p,o,n,m=a.gn(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.j())return
t=A.A(m.gk())
B.a.q(b,t)
l+=t.length+2;++k}if(!m.j()){if(k<=5)return
if(0>=b.length)return A.b(b,-1)
s=b.pop()
if(0>=b.length)return A.b(b,-1)
r=b.pop()}else{q=m.gk();++k
if(!m.j()){if(k<=4){B.a.q(b,A.A(q))
return}s=A.A(q)
if(0>=b.length)return A.b(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gk();++k
for(;m.j();q=p,p=o){o=m.gk();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.b(b,-1)
l-=b.pop().length+2;--k}B.a.q(b,"...")
return}}r=A.A(q)
s=A.A(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.b(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.q(b,n)
B.a.q(b,r)
B.a.q(b,s)},
k0(a,b){var t=B.b.gD(a)
b=B.b.gD(b)
b=A.kb(A.iu(A.iu($.jn(),t),b))
return b},
L:function L(a,b,c){this.a=a
this.b=b
this.c=c},
fM:function fM(){},
fN:function fN(){},
ew:function ew(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aD:function aD(a,b,c){this.a=a
this.b=b
this.c=c},
ey:function ey(){},
ez:function ez(){},
e0:function e0(){},
F:function F(){},
d0:function d0(a){this.a=a},
cC:function cC(){},
at:function at(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cx:function cx(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
di:function di(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
cF:function cF(a){this.a=a},
dU:function dU(a){this.a=a},
bR:function bR(a){this.a=a},
d8:function d8(a){this.a=a},
dD:function dD(){},
cB:function cB(){},
fP:function fP(a){this.a=a},
ai:function ai(a,b){this.a=a
this.b=b},
dj:function dj(){},
h:function h(){},
R:function R(a,b,c){this.a=a
this.b=b
this.$ti=c},
cv:function cv(){},
e:function e(){},
bS:function bS(a){this.a=a},
dF:function dF(a,b){this.a=a
this.b=b},
bO:function bO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ea:function ea(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
eg:function eg(){},
am:function am(a,b){this.a=a
this.b=b},
b4:function b4(a,b){this.a=a
this.b=b},
aJ:function aJ(a,b,c){this.a=a
this.b=b
this.c=c},
bD:function bD(a,b){this.a=a
this.e=b},
fz:function fz(){},
eA:function eA(){},
fH:function fH(){},
eX:function eX(){},
dG:function dG(a,b,c){this.a=a
this.b=b
this.c=c},
fA:function fA(){},
fC:function fC(){},
fD:function fD(){},
fB:function fB(a){this.a=a},
da:function da(){},
es:function es(a){this.a=a},
eu:function eu(){},
ev:function ev(){},
er:function er(a){this.a=a},
et:function et(){},
bq:function bq(a,b){this.a=a
this.b=b},
x:function x(a,b){this.a=a
this.b=b},
W:function W(a){this.a=a},
bn:function bn(){},
bM:function bM(a){this.a=a},
bQ:function bQ(a,b,c){this.a=a
this.b=b
this.c=c},
b5:function b5(a){this.a=a},
bk:function bk(){},
dd:function dd(a){this.a=a},
dL:function dL(a,b){this.a=a
this.b=b},
dS:function dS(a){this.a=a},
d_:function d_(a){this.a=a},
aM:function aM(){},
bo:function bo(a){this.a=a},
bN:function bN(a){this.a=a},
c3:function c3(){},
cD:function cD(){},
aO:function aO(a,b){this.a=a
this.b=b},
bP:function bP(a,b){this.a=a
this.b=b},
dO:function dO(a,b){this.a=a
this.b=b},
fG:function fG(){},
cz:function cz(a,b){this.a=a
this.b=b},
bl:function bl(a,b){this.a=a
this.b=b},
aN:function aN(a,b){this.a=a
this.b=b},
aB:function aB(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bm:function bm(a,b){this.a=a
this.c=b},
dW:function dW(a,b){this.a=a
this.c=b},
cy:function cy(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
d2:function d2(a,b){this.a=a
this.b=b},
db:function db(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m},
cg:function cg(a,b){this.a=a
this.b=b},
cf:function cf(a,b){this.a=a
this.b=b},
bb:function bb(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
eL:function eL(){},
eM:function eM(){},
b9:function b9(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eF:function eF(){},
ba:function ba(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eK:function eK(){},
bc:function bc(a,b){this.a=a
this.b=b},
eN:function eN(){},
eG:function eG(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
eH:function eH(){},
eI:function eI(){},
c9(a,b){return new A.Q(a,b)},
a5:function a5(a,b){this.a=a
this.b=b},
Q:function Q(a,b){this.a=a
this.b=b},
b7(a,b){return new A.bE(a,b)},
ah:function ah(a,b){this.a=a
this.b=b},
bE:function bE(a,b){this.a=a
this.b=b},
eB:function eB(a,b){this.b=a
this.c=b},
eC:function eC(a){this.a=a},
e_:function e_(a,b,c){this.a=a
this.b=b
this.c=c},
cP:function cP(a,b){this.a=a
this.b=b},
de:function de(a){this.a=a},
an:function an(a,b){this.a=a
this.b=b},
du:function du(a,b){this.a=a
this.b=b},
bp:function bp(a,b){this.a=a
this.b=b},
aw:function aw(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bU:function bU(){},
cl:function cl(){},
bA:function bA(a,b){this.a=a
this.b=b},
bT:function bT(){},
eE:function eE(a,b){this.a=a
this.b=b},
cd:function cd(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.e=d
_.f=e},
df:function df(a){this.b=a},
fE:function fE(a,b,c){this.a=a
this.b=b
this.f=c},
dg:function dg(a,b,c,d,e,f,g,h,i){var _=this
_.b=a
_.c=b
_.d=c
_.e=d
_.f=e
_.r=f
_.w=g
_.x=h
_.y=i},
eD:function eD(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i},
dT:function dT(a,b){this.a=a
this.b=b},
ce:function ce(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
eJ:function eJ(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
eb:function eb(){},
ed:function ed(a,b){this.a=a
this.b=b},
ee:function ee(a,b){this.a=a
this.b=b},
ef:function ef(){},
ec:function ec(){},
a0(a,b){return u.f.b(a)?a:A.i(A.f(b+" must be an object.",null))},
al(a,b){var t
if(u.j.b(a.h(0,b))){t=a.h(0,b)
t.toString
u.J.a(t)}else t=A.i(A.f(b+" must be a list.",null))
return t},
ad(a,b){var t
if(typeof a.h(0,b)=="string"){t=a.h(0,b)
t.toString
A.u(t)}else t=A.i(A.f(b+" must be a string.",null))
return t},
a4(a,b){var t
if(A.a2(a.h(0,b))){t=a.h(0,b)
t.toString
A.E(t)}else t=A.i(A.f(b+" must be an integer.",null))
return t},
jy(a,b){var t=J.a3(A.al(a,b),new A.ei(b),u.N)
t=A.D(t,t.$ti.i("q.E"))
return t},
U(a,b,c){var t,s,r=A.dt(b,u.N)
r.J(0,c)
t=a.gE().W(0).a2(r)
if(t.a!==0)throw A.a(A.f("Unknown key "+t.gZ(0)+".",null))
s=b.a2(a.gE().W(0)).a2(c)
if(s.a!==0)throw A.a(A.f("Missing key "+s.gZ(0)+".",null))},
aR:function aR(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ay:function ay(a,b){this.a=a
this.b=b},
az:function az(a,b){this.a=a
this.b=b},
aS:function aS(a,b,c,d,e){var _=this
_.a=a
_.c=b
_.d=c
_.e=d
_.f=e},
aH:function aH(a,b){this.a=a
this.c=b},
d4:function d4(){},
en:function en(a){this.a=a},
ep:function ep(a){this.a=a},
eo:function eo(){},
eq:function eq(a){this.a=a},
ej:function ej(a){this.a=a},
ek:function ek(a){this.a=a},
em:function em(a){this.a=a},
el:function el(a){this.a=a},
eh:function eh(a){this.a=a},
ei:function ei(a){this.a=a},
d3(a,b){var t,s,r,q=null
try{q=B.d.a1(a,null)}catch(s){r=A.hl(s)
if(r instanceof A.ai){t=r
throw A.a(A.f("INVALID_JSON: "+b,t.b))}else throw s}if(!u.f.b(q))throw A.a(A.f("JSON_OBJECT_REQUIRED: "+b,null))
return q},
c4:function c4(a){this.a=a
this.b=!1},
la(a){var t
A:{if("warmup"===a){t=B.bw
break A}if("joker"===a){t=B.bn
break A}if("deload"===a){t=B.by
break A}if("assistance"===a){t=B.bq
break A}if("conditioning"===a){t=B.bt
break A}t=null
break A}return t},
l8(a){var t,s,r,q,p,o,n,m,l,k=A.j([],u.x)
for(t=a.e,s=t.length,r=u.N,q=u.K,p=0;p<s;++p){o=t[p]
n=o.d
k.push(A.G(["index",o.a,"slotId",o.b,"role",o.c.b,"cycleReference",A.G(["templateId",n.a,"variantId",n.b,"templateRevision",n.c,"variantRevision",n.d],r,q),"cycle",o.e.t(),"trainingMaxesBefore",A.j_(o.f),"trainingMaxesAfter",A.j_(o.r)],r,q))}t=u.V
s=A.C(r,t)
for(n=a.f.gB(),n=n.gn(n);n.j();){m=n.gk()
l=m.a
m=m.b
s.l(0,l,A.G(["centiUnits",m.a,"unit",m.b.b],r,q))}t=A.C(r,t)
for(n=a.r.gB(),n=n.gn(n);n.j();){m=n.gk()
l=m.a
m=m.b
t.l(0,l,A.G(["centiUnits",m.a,"unit",m.b.b],r,q))}return A.G(["id",a.a,"definitionId",a.b,"definitionRevision",a.c.a,"state",a.d.b,"nodes",k,"initialTrainingMaxes",s,"projectedTrainingMaxes",t],r,u.X)},
j_(a){var t,s,r,q,p=u.N,o=A.C(p,u.V)
for(t=a.a.gB(),t=t.gn(t),s=u.K;t.j();){r=t.gk()
q=r.a
r=r.b
o.l(0,q,A.G(["centiUnits",r.a,"unit",r.b.b],p,s))}return A.G(["kind",a.b.b,"values",o],p,u.X)},
l9(a){var t
A:{if("overhead_press"===a){t="OP"
break A}if("bench_press"===a){t="BP"
break A}if("squat"===a){t="SQ"
break A}if("deadlift"===a){t="DL"
break A}if("squat_bench_press"===a){t="SQ+BP"
break A}if("deadlift_overhead_press"===a){t="DL+OP"
break A}t=a
break A}return t},
a1(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o){var t=A.C(u.N,u.X)
t.l(0,"id",e)
t.l(0,"path",j)
t.l(0,"region",l)
t.l(0,"kind",f)
t.l(0,"label",g)
t.l(0,"value",n)
if(b!=null)t.l(0,"choices",b)
if(c!=null)t.l(0,"group",c)
if(d!=null)t.l(0,"groupLabel",d)
if(i!=null)t.l(0,"minimum",i)
if(h!=null)t.l(0,"maximum",h)
if(m!=null)t.l(0,"step",m)
if(a!=null)t.l(0,"action",a)
if(k!=null)t.l(0,"readOnly",k)
if(o!=null)t.l(0,"visibleWhen",o)
return t},
H(a,b){return u.f.b(a)?a:A.i(A.f(b+" must be an object",null))},
aZ(a,b){var t
if(u.j.b(a.h(0,b))){t=a.h(0,b)
t.toString
u.J.a(t)}else t=A.i(A.f(b+" must be a list",null))
return t},
T(a,b){var t
if(typeof a.h(0,b)=="string"){t=a.h(0,b)
t.toString
A.u(t)}else t=A.i(A.f(b+" must be a string",null))
return t},
aX(a,b){var t
if(A.a2(a.h(0,b))){t=a.h(0,b)
t.toString
A.E(t)}else t=A.i(A.f(b+" must be an integer",null))
return t},
h7(a,b){var t=J.a3(A.aZ(a,b),new A.h8(),u.N)
t=A.D(t,t.$ti.i("q.E"))
t.$flags=1
return t},
hO(a,b){var t=J.a3(A.aZ(a,b),new A.h4(),u.S)
t=A.D(t,t.$ti.i("q.E"))
t.$flags=1
return t},
h9(a){return new A.x(A.aX(a,"centiUnits"),A.av(B.h,A.T(a,"unit"),u.r))},
ld(a,b){var t,s,r,q,p,o=a.length
if(o===b.length){t=J.ia(o,u.y)
for(s=a.length,r=b.length,q=0;q<o;++q){if(!(q<s))return A.b(a,q)
p=a[q]
if(!(q<r))return A.b(b,q)
t[q]=p===b[q]}o=B.a.cp(t,new A.h6())}else o=!1
return o},
aY(a,b){var t,s=a.gE().W(0).a2(b)
if(s.a!==0)throw A.a(A.f("Unknown key "+s.gZ(0),null))
t=b.a2(a.gE().W(0))
if(t.a!==0)throw A.a(A.f("Missing key "+t.gZ(0),null))},
hQ(a,b){var t=a.gE().W(0).a2(b)
if(t.a!==0)throw A.a(A.f("UNKNOWN_KEY:"+t.gZ(0),null))},
h5(a){if(!J.N(a.h(0,"apiVersion"),"v1")||!J.N(a.h(0,"schemaVersion"),1))throw A.a(B.aN)},
e7(a){var t,s
if(u.j.b(a))return"["+J.a3(a,A.lr(),u.N).aM(0,",")+"]"
if(u.I.b(a)){t=a.gE()
t=A.i3(t,A.k(t).i("h.E"),u.N)
s=A.D(t,A.k(t).i("h.E"))
B.a.bp(s)
t=A.y(s)
return"{"+new A.I(s,t.i("d(1)").a(new A.h2(a)),t.i("I<1,d>")).aM(0,",")+"}"}return B.d.K(a,null)},
hM(a){var t,s,r=A.iE("cbf29ce484222325",16),q=A.iE("100000001b3",16),p=$.aA(),o=p.X(0,64).a9(0,p)
for(p=B.a5.cf(a),t=p.length,s=0;s<t;++s)r=r.br(0,A.kg(p[s])).a3(0,q).bn(0,o)
return"fnv1a64-"+B.f.cB(r.aP(0,16),16,"0")},
co:function co(a,b,c,d,e,f,g,h,i){var _=this
_.f=_.e=null
_.r=a
_.w=b
_.x=c
_.y=d
_.z=e
_.Q=f
_.as=g
_.at=h
_.ax=i},
fk:function fk(){},
fl:function fl(){},
fm:function fm(){},
fn:function fn(){},
fo:function fo(){},
fp:function fp(){},
fq:function fq(){},
fr:function fr(){},
fs:function fs(){},
ft:function ft(){},
f8:function f8(a){this.a=a},
f9:function f9(){},
fa:function fa(a){this.a=a},
fb:function fb(a){this.a=a},
fc:function fc(a){this.a=a},
fd:function fd(a){this.a=a},
fe:function fe(a){this.a=a},
ff:function ff(a){this.a=a},
fg:function fg(){},
fh:function fh(){},
fi:function fi(a){this.a=a},
fj:function fj(a){this.a=a},
eY:function eY(){},
eZ:function eZ(){},
f_:function f_(a){this.a=a},
f0:function f0(a){this.a=a},
f3:function f3(a){this.a=a},
f4:function f4(a){this.a=a},
f5:function f5(a){this.a=a},
f2:function f2(a){this.a=a},
f6:function f6(a,b){this.a=a
this.b=b},
f1:function f1(){},
f7:function f7(a){this.a=a},
dY:function dY(a){this.a=a},
h8:function h8(){},
h4:function h4(){},
h6:function h6(){},
h2:function h2(a){this.a=a},
lG(){v.G.globalThis.hybridTrainingEngine=new A.hj(new A.dh(new A.c4(new A.co(B.b4,B.b5,B.b6,B.l,B.l,B.l,B.l,B.bG,B.bH)))).$0()},
dh:function dh(a){this.a=a},
hi:function hi(a){this.a=a},
hj:function hj(a){this.a=a},
iV(a){var t
if(typeof a=="function")throw A.a(A.bB("Attempting to rewrap a JS function."))
t=function(b,c){return function(){return b(c)}}(A.kK,a)
t[$.hm()]=a
return t},
cZ(a){var t
if(typeof a=="function")throw A.a(A.bB("Attempting to rewrap a JS function."))
t=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.kL,a)
t[$.hm()]=a
return t},
kK(a){return u.Z.a(a).$0()},
kL(a,b,c){u.Z.a(a)
if(A.E(c)>=1)return a.$1(b)
return a.$0()}},B={}
var w=[A,J,B]
var $={}
A.ht.prototype={}
J.dk.prototype={
a_(a,b){return a===b},
gD(a){return A.dJ(a)},
m(a){return"Instance of '"+A.dK(a)+"'"},
gF(a){return A.bw(A.hN(this))}}
J.dm.prototype={
m(a){return String(a)},
gD(a){return a?519018:218159},
gF(a){return A.bw(u.y)},
$iB:1,
$io:1}
J.ci.prototype={
a_(a,b){return null==b},
m(a){return"null"},
gD(a){return 0},
$iB:1}
J.cj.prototype={$iP:1}
J.aL.prototype={
gD(a){return 0},
m(a){return String(a)}}
J.dE.prototype={}
J.bV.prototype={}
J.aF.prototype={
m(a){var t=a[$.j8()]
if(t==null)t=a[$.hm()]
if(t==null)return this.bq(a)
return"JavaScript function for "+J.b1(t)},
$ib8:1}
J.bH.prototype={
gD(a){return 0},
m(a){return String(a)}}
J.bI.prototype={
gD(a){return 0},
m(a){return String(a)}}
J.l.prototype={
ac(a,b){return new A.aC(a,A.y(a).i("@<1>").u(b).i("aC<1,2>"))},
q(a,b){A.y(a).c.a(b)
a.$flags&1&&A.J(a,29)
a.push(b)},
J(a,b){var t
A.y(a).i("h<1>").a(b)
a.$flags&1&&A.J(a,"addAll",2)
if(Array.isArray(b)){this.bw(a,b)
return}for(t=J.O(b);t.j();)a.push(t.gk())},
bw(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.a(A.V(a))
for(s=0;s<t;++s)a.push(b[s])},
a8(a,b,c){var t=A.y(a)
return new A.I(a,t.u(c).i("1(2)").a(b),t.i("@<1>").u(c).i("I<1,2>"))},
bk(a,b,c,d){var t,s,r
d.a(b)
A.y(a).u(d).i("1(1,2)").a(c)
t=a.length
for(s=b,r=0;r<t;++r){s=c.$2(s,a[r])
if(a.length!==t)throw A.a(A.V(a))}return s},
cr(a,b){var t,s,r
A.y(a).i("o(1)").a(b)
t=a.length
for(s=0;s<t;++s){r=a[s]
if(b.$1(r))return r
if(a.length!==t)throw A.a(A.V(a))}throw A.a(A.bF())},
I(a,b){var t,s,r,q,p,o=A.y(a)
o.i("o(1)").a(b)
t=a.length
for(s=null,r=!1,q=0;q<t;++q){p=a[q]
if(b.$1(p)){if(r)throw A.a(A.hr())
s=p
r=!0}if(t!==a.length)throw A.a(A.V(a))}if(r)return s==null?o.c.a(s):s
throw A.a(A.bF())},
C(a,b){if(!(b>=0&&b<a.length))return A.b(a,b)
return a[b]},
gZ(a){if(a.length>0)return a[0]
throw A.a(A.bF())},
gai(a){var t=a.length
if(t===1){if(0>=t)return A.b(a,0)
return a[0]}if(t===0)throw A.a(A.bF())
throw A.a(A.hr())},
N(a,b){var t,s
A.y(a).i("o(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.a(A.V(a))}return!1},
cp(a,b){var t,s
A.y(a).i("o(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(!b.$1(a[s]))return!1
if(a.length!==t)throw A.a(A.V(a))}return!0},
aU(a,b){var t,s,r,q,p,o=A.y(a)
o.i("c(1,1)?").a(b)
a.$flags&2&&A.J(a,"sort")
t=a.length
if(t<2)return
if(b==null)b=J.kW()
if(t===2){s=a[0]
r=a[1]
o=b.$2(s,r)
if(typeof o!=="number")return o.cO()
if(o>0){a[0]=r
a[1]=s}return}q=0
if(o.c.b(null))for(p=0;p<a.length;++p)if(a[p]===void 0){a[p]=null;++q}a.sort(A.lm(b,2))
if(q>0)this.bX(a,q)},
bp(a){return this.aU(a,null)},
bX(a,b){var t,s=a.length
for(;t=s-1,s>0;s=t)if(a[t]===null){a[t]=void 0;--b
if(b===0)break}},
H(a,b){var t
for(t=0;t<a.length;++t)if(J.N(a[t],b))return!0
return!1},
gv(a){return a.length===0},
gV(a){return a.length!==0},
m(a){return A.hs(a,"[","]")},
gn(a){return new J.b2(a,a.length,A.y(a).i("b2<1>"))},
gD(a){return A.dJ(a)},
gp(a){return a.length},
h(a,b){if(!(b>=0&&b<a.length))throw A.a(A.ha(a,b))
return a[b]},
l(a,b,c){A.y(a).c.a(c)
a.$flags&2&&A.J(a)
if(!(b>=0&&b<a.length))throw A.a(A.ha(a,b))
a[b]=c},
$in:1,
$ih:1,
$ip:1}
J.dl.prototype={
cK(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.dK(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.eO.prototype={}
J.b2.prototype={
gk(){var t=this.d
return t==null?this.$ti.c.a(t):t},
j(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.v(r)
throw A.a(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$iM:1}
J.bG.prototype={
Y(a,b){var t
A.hK(b)
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gaL(b)
if(this.gaL(a)===t)return 0
if(this.gaL(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gaL(a){return a===0?1/a<0:a<0},
aO(a){var t
if(a>=-2147483648&&a<=2147483647)return a|0
if(isFinite(a)){t=a<0?Math.ceil(a):Math.floor(a)
return t+0}throw A.a(A.cG(""+a+".toInt()"))},
cb(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.a(A.cG(""+a+".ceil()"))},
cH(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.a(A.cG(""+a+".round()"))},
aP(a,b){var t,s,r,q,p
if(b<2||b>36)throw A.a(A.ap(b,2,36,"radix",null))
t=a.toString(b)
s=t.length
r=s-1
if(!(r>=0))return A.b(t,r)
if(t.charCodeAt(r)!==41)return t
q=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(t)
if(q==null)A.i(A.cG("Unexpected toString result: "+t))
s=q.length
if(1>=s)return A.b(q,1)
t=q[1]
if(3>=s)return A.b(q,3)
p=+q[3]
s=q[2]
if(s!=null){t+=s
p-=s.length}return t+B.f.a3("0",p)},
m(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gD(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
O(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
aV(a,b){if((a|0)===a)if(b>=1||b<-1)return a/b|0
return this.bc(a,b)},
A(a,b){return(a|0)===a?a/b|0:this.bc(a,b)},
bc(a,b){var t=a/b
if(t>=-2147483648&&t<=2147483647)return t|0
if(t>0){if(t!==1/0)return Math.floor(t)}else if(t>-1/0)return Math.ceil(t)
throw A.a(A.cG("Result of truncating division is "+A.A(t)+": "+A.A(a)+" ~/ "+b))},
X(a,b){if(b<0)throw A.a(A.c_(b))
return b>31?0:a<<b>>>0},
az(a,b){return b>31?0:a<<b>>>0},
a4(a,b){var t
if(a>0)t=this.bb(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
aA(a,b){if(0>b)throw A.a(A.c_(b))
return this.bb(a,b)},
bb(a,b){return b>31?0:a>>>b},
gF(a){return A.bw(u.H)},
$ia9:1,
$ir:1,
$iab:1}
J.ch.prototype={
gbg(a){var t,s=a<0?-a-1:a,r=s
for(t=32;r>=4294967296;){r=this.A(r,4294967296)
t+=32}return t-Math.clz32(r)},
gF(a){return A.bw(u.S)},
$iB:1,
$ic:1}
J.dn.prototype={
gF(a){return A.bw(u.i)},
$iB:1}
J.bd.prototype={
a5(a,b,c){return a.substring(b,A.ip(b,c,a.length))},
cJ(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.b(q,0)
if(q.charCodeAt(0)===133){t=J.jR(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.b(q,s)
r=q.charCodeAt(s)===133?J.jS(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
a3(a,b){var t,s
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.a(B.Z)
for(t=a,s="";;){if((b&1)===1)s=t+s
b=b>>>1
if(b===0)break
t+=t}return s},
cB(a,b,c){var t=b-a.length
if(t<=0)return a
return this.a3(c,t)+a},
H(a,b){return A.lJ(a,b,0)},
Y(a,b){var t
A.u(b)
if(a===b)t=0
else t=a<b?-1:1
return t},
m(a){return a},
gD(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gF(a){return A.bw(u.N)},
gp(a){return a.length},
$iB:1,
$ia9:1,
$ify:1,
$id:1}
A.aU.prototype={
gn(a){return new A.c5(J.O(this.ga0()),A.k(this).i("c5<1,2>"))},
gp(a){return J.c2(this.ga0())},
gv(a){return J.hX(this.ga0())},
gV(a){return J.ju(this.ga0())},
C(a,b){return A.k(this).y[1].a(J.hn(this.ga0(),b))},
m(a){return J.b1(this.ga0())}}
A.c5.prototype={
j(){return this.a.j()},
gk(){return this.$ti.y[1].a(this.a.gk())},
$iM:1}
A.b3.prototype={
ga0(){return this.a}}
A.cJ.prototype={$in:1}
A.cI.prototype={
h(a,b){return this.$ti.y[1].a(J.jp(this.a,b))},
$in:1,
$ip:1}
A.aC.prototype={
ac(a,b){return new A.aC(this.a,this.$ti.i("@<1>").u(b).i("aC<1,2>"))},
ga0(){return this.a}}
A.bJ.prototype={
m(a){return"LateInitializationError: "+this.a}}
A.fF.prototype={}
A.n.prototype={}
A.q.prototype={
gn(a){var t=this
return new A.bg(t,t.gp(t),A.k(t).i("bg<q.E>"))},
gv(a){return this.gp(this)===0},
I(a,b){var t,s,r,q,p,o=this
A.k(o).i("o(q.E)").a(b)
t=o.gp(o)
s=A.dZ("match")
for(r=!1,q=0;q<t;++q){p=o.C(0,q)
if(b.$1(p)){if(r)throw A.a(A.hr())
s.b=p
r=!0}if(t!==o.gp(o))throw A.a(A.V(o))}if(r)return s.bT()
throw A.a(A.bF())},
aM(a,b){var t,s,r,q=this,p=q.gp(q)
if(b.length!==0){if(p===0)return""
t=A.A(q.C(0,0))
if(p!==q.gp(q))throw A.a(A.V(q))
for(s=t,r=1;r<p;++r){s=s+b+A.A(q.C(0,r))
if(p!==q.gp(q))throw A.a(A.V(q))}return s.charCodeAt(0)==0?s:s}else{for(r=0,s="";r<p;++r){s+=A.A(q.C(0,r))
if(p!==q.gp(q))throw A.a(A.V(q))}return s.charCodeAt(0)==0?s:s}},
cw(a){return this.aM(0,"")},
a8(a,b,c){var t=A.k(this)
return new A.I(this,t.u(c).i("1(q.E)").a(b),t.i("@<q.E>").u(c).i("I<1,2>"))},
cC(a,b){var t,s,r,q=this
A.k(q).i("q.E(q.E,q.E)").a(b)
t=q.gp(q)
if(t===0)throw A.a(A.bF())
s=q.C(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.C(0,r))
if(t!==q.gp(q))throw A.a(A.V(q))}return s},
W(a){var t,s=this,r=A.hv(A.k(s).i("q.E"))
for(t=0;t<s.gp(s);++t)r.q(0,s.C(0,t))
return r}}
A.bg.prototype={
gk(){var t=this.d
return t==null?this.$ti.c.a(t):t},
j(){var t,s=this,r=s.a,q=J.hc(r),p=q.gp(r)
if(s.b!==p)throw A.a(A.V(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.C(r,t);++s.c
return!0},
$iM:1}
A.bh.prototype={
gn(a){return new A.cp(J.O(this.a),this.b,A.k(this).i("cp<1,2>"))},
gp(a){return J.c2(this.a)},
gv(a){return J.hX(this.a)},
C(a,b){return this.b.$1(J.hn(this.a,b))}}
A.ca.prototype={$in:1}
A.cp.prototype={
j(){var t=this,s=t.b
if(s.j()){t.a=t.c.$1(s.gk())
return!0}t.a=null
return!1},
gk(){var t=this.a
return t==null?this.$ti.y[1].a(t):t},
$iM:1}
A.I.prototype={
gp(a){return J.c2(this.a)},
C(a,b){return this.b.$1(J.hn(this.a,b))}}
A.aa.prototype={
gn(a){return new A.Z(J.O(this.a),this.b,this.$ti.i("Z<1>"))}}
A.Z.prototype={
j(){var t,s
for(t=this.a,s=this.b;t.j();)if(s.$1(t.gk()))return!0
return!1},
gk(){return this.a.gk()},
$iM:1}
A.b6.prototype={
gn(a){return new A.cc(J.O(this.a),this.b,B.S,this.$ti.i("cc<1,2>"))}}
A.cc.prototype={
gk(){var t=this.d
return t==null?this.$ti.y[1].a(t):t},
j(){var t,s,r=this,q=r.c
if(q==null)return!1
for(t=r.a,s=r.b;!q.j();){r.d=null
if(t.j()){r.c=null
q=J.O(s.$1(t.gk()))
r.c=q}else return!1}r.d=r.c.gk()
return!0},
$iM:1}
A.cb.prototype={
j(){return!1},
gk(){throw A.a(A.bF())},
$iM:1}
A.a6.prototype={}
A.aP.prototype={
gp(a){return J.c2(this.a)},
C(a,b){var t=this.a,s=J.hc(t)
return s.C(t,s.gp(t)-1-b)}}
A.cX.prototype={}
A.c7.prototype={}
A.c6.prototype={
gv(a){return this.gp(this)===0},
m(a){return A.fv(this)},
gB(){return new A.bW(this.co(),A.k(this).i("bW<R<1,2>>"))},
co(){var t=this
return function(){var s=0,r=1,q=[],p,o,n,m,l
return function $async$gB(a,b,c){if(b===1){q.push(c)
s=r}for(;;)switch(s){case 0:p=t.gE(),p=p.gn(p),o=A.k(t),n=o.y[1],o=o.i("R<1,2>")
case 2:if(!p.j()){s=3
break}m=p.gk()
l=t.h(0,m)
s=4
return a.b=new A.R(m,l==null?n.a(l):l,o),1
case 4:s=2
break
case 3:return 0
case 1:return a.c=q.at(-1),3}}}},
$im:1}
A.t.prototype={
gp(a){return this.b.length},
gb2(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
G(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.G(b))return null
return this.b[this.a[b]]},
T(a,b){var t,s,r,q
this.$ti.i("~(1,2)").a(b)
t=this.gb2()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])},
gE(){return new A.cK(this.gb2(),this.$ti.i("cK<1>"))}}
A.cK.prototype={
gp(a){return this.a.length},
gv(a){return 0===this.a.length},
gV(a){return 0!==this.a.length},
gn(a){var t=this.a
return new A.br(t,t.length,this.$ti.i("br<1>"))}}
A.br.prototype={
gk(){var t=this.d
return t==null?this.$ti.c.a(t):t},
j(){var t=this,s=t.c
if(s>=t.b){t.d=null
return!1}t.d=t.a[s]
t.c=s+1
return!0},
$iM:1}
A.c8.prototype={
q(a,b){A.k(this).c.a(b)
A.jE()}}
A.w.prototype={
gp(a){return this.b},
gv(a){return this.b===0},
gV(a){return this.b!==0},
gn(a){var t,s=this,r=s.$keys
if(r==null){r=Object.keys(s.a)
s.$keys=r}t=r
return new A.br(t,t.length,s.$ti.i("br<1>"))},
H(a,b){if(typeof b!="string")return!1
if("__proto__"===b)return!1
return this.a.hasOwnProperty(b)},
W(a){return A.dt(this,this.$ti.c)}}
A.cA.prototype={}
A.fI.prototype={
U(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
if(q==null)return null
t=Object.create(null)
s=r.b
if(s!==-1)t.arguments=q[s+1]
s=r.c
if(s!==-1)t.argumentsExpr=q[s+1]
s=r.d
if(s!==-1)t.expr=q[s+1]
s=r.e
if(s!==-1)t.method=q[s+1]
s=r.f
if(s!==-1)t.receiver=q[s+1]
return t}}
A.cw.prototype={
m(a){return"Null check operator used on a null value"}}
A.dq.prototype={
m(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.dV.prototype={
m(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.fx.prototype={
m(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.aK.prototype={
m(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.j7(s==null?"unknown":s)+"'"},
$ib8:1,
gcN(){return this},
$C:"$1",
$R:1,
$D:null}
A.d5.prototype={$C:"$0",$R:0}
A.d6.prototype={$C:"$2",$R:2}
A.dR.prototype={}
A.dQ.prototype={
m(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.j7(t)+"'"}}
A.bC.prototype={
a_(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.bC))return!1
return this.$_target===b.$_target&&this.a===b.a},
gD(a){return(A.j4(this.a)^A.dJ(this.$_target))>>>0},
m(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.dK(this.a)+"'")}}
A.dM.prototype={
m(a){return"RuntimeError: "+this.a}}
A.aG.prototype={
gp(a){return this.a},
gv(a){return this.a===0},
gE(){return new A.ao(this,A.k(this).i("ao<1>"))},
gB(){return new A.a7(this,A.k(this).i("a7<1,2>"))},
G(a){var t,s
if(typeof a=="string"){t=this.b
if(t==null)return!1
return t[a]!=null}else if(typeof a=="number"&&(a&0x3fffffff)===a){s=this.c
if(s==null)return!1
return s[a]!=null}else return this.ct(a)},
ct(a){var t=this.d
if(t==null)return!1
return this.aJ(t[this.aI(a)],a)>=0},
J(a,b){A.k(this).i("m<1,2>").a(b).T(0,new A.eP(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.cu(b)},
cu(a){var t,s,r=this.d
if(r==null)return null
t=r[this.aI(a)]
s=this.aJ(t,a)
if(s<0)return null
return t[s].b},
l(a,b,c){var t,s,r=this,q=A.k(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.aW(t==null?r.b=r.ar():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.aW(s==null?r.c=r.ar():s,b,c)}else r.cv(b,c)},
cv(a,b){var t,s,r,q,p=this,o=A.k(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.ar()
s=p.aI(a)
r=t[s]
if(r==null)t[s]=[p.aj(a,b)]
else{q=p.aJ(r,a)
if(q>=0)r[q].b=b
else r.push(p.aj(a,b))}},
T(a,b){var t,s,r=this
A.k(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.a(A.V(r))
t=t.c}},
aW(a,b,c){var t,s=A.k(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.aj(b,c)
else t.b=c},
aj(a,b){var t=this,s=A.k(t),r=new A.eS(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
aI(a){return J.e9(a)&1073741823},
aJ(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.N(a[s].a,b))return s
return-1},
m(a){return A.fv(this)},
ar(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$iid:1}
A.eP.prototype={
$2(a,b){var t=this.a,s=A.k(t)
t.l(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.k(this.a).i("~(1,2)")}}
A.eS.prototype={}
A.ao.prototype={
gp(a){return this.a.a},
gv(a){return this.a.a===0},
gn(a){var t=this.a
return new A.be(t,t.r,t.e,this.$ti.i("be<1>"))},
H(a,b){return this.a.G(b)}}
A.be.prototype={
gk(){return this.d},
j(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.a(A.V(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$iM:1}
A.bf.prototype={
gp(a){return this.a.a},
gv(a){return this.a.a===0},
gn(a){var t=this.a
return new A.cn(t,t.r,t.e,this.$ti.i("cn<1>"))}}
A.cn.prototype={
gk(){return this.d},
j(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.a(A.V(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.b
s.c=t.c
return!0}},
$iM:1}
A.a7.prototype={
gp(a){return this.a.a},
gv(a){return this.a.a===0},
gn(a){var t=this.a
return new A.cm(t,t.r,t.e,this.$ti.i("cm<1,2>"))}}
A.cm.prototype={
gk(){var t=this.d
t.toString
return t},
j(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.a(A.V(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.R(t.a,t.b,s.$ti.i("R<1,2>"))
s.c=t.c
return!0}},
$iM:1}
A.he.prototype={
$1(a){return this.a(a)},
$S:12}
A.hf.prototype={
$2(a,b){return this.a(a,b)},
$S:39}
A.hg.prototype={
$1(a){return this.a(A.u(a))},
$S:42}
A.dp.prototype={
m(a){return"RegExp/"+this.a+"/"+this.b.flags},
bj(a){var t=this.b.exec(a)
if(t==null)return null
return new A.fV(t)},
$ify:1,
$ik7:1}
A.fV.prototype={}
A.fO.prototype={
bT(){var t=this.b
if(t===this)throw A.a(new A.bJ("Local '"+this.a+"' has not been initialized."))
return t},
M(){var t=this.b
if(t===this)throw A.a(new A.bJ("Field '"+this.a+"' has not been initialized."))
return t}}
A.bi.prototype={
gF(a){return B.cL},
c9(a,b,c){var t=new DataView(a,b)
return t},
bf(a){return this.c9(a,0,null)},
$iB:1,
$ibi:1}
A.cs.prototype={
gca(a){if(((a.$flags|0)&2)!==0)return new A.fZ(a.buffer)
else return a.buffer}}
A.fZ.prototype={
bf(a){var t=A.jZ(this.a,0,null)
t.$flags=3
return t}}
A.dv.prototype={
gF(a){return B.cM},
$iB:1}
A.bL.prototype={
gp(a){return a.length},
$iae:1}
A.cq.prototype={
h(a,b){A.bu(b,a,a.length)
return a[b]},
$in:1,
$ih:1,
$ip:1}
A.cr.prototype={$in:1,$ih:1,$ip:1}
A.dw.prototype={
gF(a){return B.cN},
$iB:1}
A.dx.prototype={
gF(a){return B.cO},
$iB:1}
A.dy.prototype={
gF(a){return B.cP},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1}
A.dz.prototype={
gF(a){return B.cQ},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1}
A.dA.prototype={
gF(a){return B.cR},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1}
A.dB.prototype={
gF(a){return B.cT},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1,
$ihy:1}
A.dC.prototype={
gF(a){return B.cU},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1}
A.ct.prototype={
gF(a){return B.cV},
gp(a){return a.length},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1}
A.cu.prototype={
gF(a){return B.cW},
gp(a){return a.length},
h(a,b){A.bu(b,a,a.length)
return a[b]},
$iB:1,
$ihz:1}
A.cL.prototype={}
A.cM.prototype={}
A.cN.prototype={}
A.cO.prototype={}
A.aq.prototype={
i(a){return A.fY(v.typeUniverse,this,a)},
u(a){return A.kD(v.typeUniverse,this,a)}}
A.e2.prototype={}
A.fW.prototype={
m(a){return A.af(this.a,null)}}
A.e1.prototype={
m(a){return this.a}}
A.cS.prototype={}
A.cR.prototype={
gk(){var t=this.b
return t==null?this.$ti.c.a(t):t},
c0(a,b){var t,s,r
a=A.E(a)
b=b
t=this.a
for(;;)try{s=t(this,a,b)
return s}catch(r){b=r
a=1}},
j(){var t,s,r,q,p=this,o=null,n=0
for(;;){t=p.d
if(t!=null)try{if(t.j()){p.b=t.gk()
return!0}else p.d=null}catch(s){o=s
n=1
p.d=null}r=p.c0(n,o)
if(1===r)return!0
if(0===r){p.b=null
q=p.e
if(q==null||q.length===0){p.a=A.iL
return!1}if(0>=q.length)return A.b(q,-1)
p.a=q.pop()
n=0
o=null
continue}if(2===r){n=0
o=null
continue}if(3===r){o=p.c
p.c=null
q=p.e
if(q==null||q.length===0){p.b=null
p.a=A.iL
throw o
return!1}if(0>=q.length)return A.b(q,-1)
p.a=q.pop()
n=1
continue}throw A.a(A.dP("sync*"))}return!1},
cP(a){var t,s,r=this
if(a instanceof A.bW){t=a.a()
s=r.e
if(s==null)s=r.e=[]
B.a.q(s,r.a)
r.a=t
return 2}else{r.d=J.O(a)
return 2}},
$iM:1}
A.bW.prototype={
gn(a){return new A.cR(this.a(),this.$ti.i("cR<1>"))}}
A.ar.prototype={
b4(){return new A.ar(A.k(this).i("ar<1>"))},
gn(a){var t=this,s=new A.bs(t,t.r,A.k(t).i("bs<1>"))
s.c=t.e
return s},
gp(a){return this.a},
gv(a){return this.a===0},
gV(a){return this.a!==0},
H(a,b){var t,s
if(typeof b=="string"&&b!=="__proto__"){t=this.b
if(t==null)return!1
return u.g.a(t[b])!=null}else if(typeof b=="number"&&(b&1073741823)===b){s=this.c
if(s==null)return!1
return u.g.a(s[b])!=null}else return this.bE(b)},
bE(a){var t=this.d
if(t==null)return!1
return this.aq(t[this.an(a)],a)>=0},
gZ(a){var t=this.e
if(t==null)throw A.a(A.dP("No elements"))
return A.k(this).c.a(t.a)},
q(a,b){var t,s,r=this
A.k(r).c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.aX(t==null?r.b=A.hG():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.aX(s==null?r.c=A.hG():s,b)}else return r.bv(b)},
bv(a){var t,s,r,q=this
A.k(q).c.a(a)
t=q.d
if(t==null)t=q.d=A.hG()
s=q.an(a)
r=t[s]
if(r==null)t[s]=[q.au(a)]
else{if(q.aq(r,a)>=0)return!1
r.push(q.au(a))}return!0},
cD(a,b){var t=this
if(typeof b=="string"&&b!=="__proto__")return t.b8(t.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return t.b8(t.c,b)
else return t.bV(b)},
bV(a){var t,s,r,q,p=this,o=p.d
if(o==null)return!1
t=p.an(a)
s=o[t]
r=p.aq(s,a)
if(r<0)return!1
q=s.splice(r,1)[0]
if(0===s.length)delete o[t]
p.bd(q)
return!0},
aX(a,b){A.k(this).c.a(b)
if(u.g.a(a[b])!=null)return!1
a[b]=this.au(b)
return!0},
b8(a,b){var t
if(a==null)return!1
t=u.g.a(a[b])
if(t==null)return!1
this.bd(t)
delete a[b]
return!0},
b3(){this.r=this.r+1&1073741823},
au(a){var t,s=this,r=new A.e5(A.k(s).c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.b3()
return r},
bd(a){var t=this,s=a.c,r=a.b
if(s==null)t.e=r
else s.b=r
if(r==null)t.f=s
else r.c=s;--t.a
t.b3()},
an(a){return J.e9(a)&1073741823},
aq(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.N(a[s].a,b))return s
return-1},
$iig:1}
A.e5.prototype={}
A.bs.prototype={
gk(){var t=this.d
return t==null?this.$ti.c.a(t):t},
j(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.a(A.V(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$iM:1}
A.eT.prototype={
$2(a,b){this.a.l(0,this.b.a(a),this.c.a(b))},
$S:43}
A.z.prototype={
gn(a){return new A.bg(a,this.gp(a),A.b0(a).i("bg<z.E>"))},
C(a,b){return this.h(a,b)},
gv(a){return this.gp(a)===0},
gV(a){return!this.gv(a)},
N(a,b){var t,s
A.b0(a).i("o(z.E)").a(b)
t=this.gp(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gp(a))throw A.a(A.V(a))}return!1},
a8(a,b,c){var t=A.b0(a)
return new A.I(a,t.u(c).i("1(z.E)").a(b),t.i("@<z.E>").u(c).i("I<1,2>"))},
ac(a,b){return new A.aC(a,A.b0(a).i("@<z.E>").u(b).i("aC<1,2>"))},
m(a){return A.hs(a,"[","]")}}
A.K.prototype={
T(a,b){var t,s,r,q=A.k(this)
q.i("~(K.K,K.V)").a(b)
for(t=this.gE(),t=t.gn(t),q=q.i("K.V");t.j();){s=t.gk()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
gB(){return this.gE().a8(0,new A.fu(this),A.k(this).i("R<K.K,K.V>"))},
cA(a,b,c,d){var t,s,r,q,p,o=A.k(this)
o.u(c).u(d).i("R<1,2>(K.K,K.V)").a(b)
t=A.C(c,d)
for(s=this.gE(),s=s.gn(s),o=o.i("K.V");s.j();){r=s.gk()
q=this.h(0,r)
p=b.$2(r,q==null?o.a(q):q)
t.l(0,p.a,p.b)}return t},
G(a){return this.gE().H(0,a)},
gp(a){var t=this.gE()
return t.gp(t)},
gv(a){var t=this.gE()
return t.gv(t)},
m(a){return A.fv(this)},
$im:1}
A.fu.prototype={
$1(a){var t=this.a,s=A.k(t)
s.i("K.K").a(a)
t=t.h(0,a)
if(t==null)t=s.i("K.V").a(t)
return new A.R(a,t,s.i("R<K.K,K.V>"))},
$S(){return A.k(this.a).i("R<K.K,K.V>(K.K)")}}
A.fw.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.A(a)
s.a=(s.a+=t)+": "
t=A.A(b)
s.a+=t},
$S:7}
A.cW.prototype={}
A.bK.prototype={
h(a,b){return this.a.h(0,b)},
G(a){return this.a.G(a)},
T(a,b){this.a.T(0,this.$ti.i("~(1,2)").a(b))},
gv(a){return this.a.a===0},
gp(a){return this.a.a},
gE(){var t=this.a
return new A.ao(t,A.k(t).i("ao<1>"))},
m(a){return A.fv(this.a)},
gB(){var t=this.a
return new A.a7(t,A.k(t).i("a7<1,2>"))},
$im:1}
A.cE.prototype={}
A.aQ.prototype={
gv(a){return this.gp(this)===0},
gV(a){return this.gp(this)!==0},
J(a,b){var t
A.k(this).i("h<1>").a(b)
for(t=b.gn(b);t.j();)this.q(0,t.gk())},
ce(a){var t,s,r
for(t=A.fU(a,a.r,A.k(a).c),s=t.$ti.c;t.j();){r=t.d
if(!this.H(0,r==null?s.a(r):r))return!1}return!0},
a2(a){var t,s,r=this.W(0)
for(t=this.gn(this);t.j();){s=t.gk()
if(a.H(0,s))r.cD(0,s)}return r},
m(a){return A.hs(this,"{","}")},
C(a,b){var t,s
A.hw(b,"index")
t=this.gn(this)
for(s=b;t.j();){if(s===0)return t.gk();--s}throw A.a(A.hq(b,b-s,this,"index"))},
$in:1,
$ih:1,
$idN:1}
A.cQ.prototype={
a2(a){var t,s,r,q=this,p=q.b4()
for(t=A.fU(q,q.r,A.k(q).c),s=t.$ti.c;t.j();){r=t.d
if(r==null)r=s.a(r)
if(!a.H(0,r))p.q(0,r)}return p},
W(a){var t=this.b4()
t.J(0,this)
return t}}
A.bX.prototype={}
A.e3.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.bS(b):t}},
gp(a){return this.b==null?this.c.a:this.aa().length},
gv(a){return this.gp(0)===0},
gE(){if(this.b==null){var t=this.c
return new A.ao(t,A.k(t).i("ao<1>"))}return new A.e4(this)},
G(a){if(this.b==null)return this.c.G(a)
return Object.prototype.hasOwnProperty.call(this.a,a)},
T(a,b){var t,s,r,q,p=this
u.cA.a(b)
if(p.b==null)return p.c.T(0,b)
t=p.aa()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.h3(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.a(A.V(p))}},
aa(){var t=u.bM.a(this.c)
if(t==null)t=this.c=A.j(Object.keys(this.a),u.s)
return t},
bS(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.h3(this.a[a])
return this.b[a]=t}}
A.e4.prototype={
gp(a){return this.a.gp(0)},
C(a,b){var t=this.a
if(t.b==null)t=t.gE().C(0,b)
else{t=t.aa()
if(!(b>=0&&b<t.length))return A.b(t,b)
t=t[b]}return t},
gn(a){var t=this.a
if(t.b==null){t=t.gE()
t=t.gn(t)}else{t=t.aa()
t=new J.b2(t,t.length,A.y(t).i("b2<1>"))}return t},
H(a,b){return this.a.G(b)}}
A.d7.prototype={}
A.d9.prototype={}
A.ck.prototype={
m(a){var t=A.dc(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.ds.prototype={
m(a){return"Cyclic error in JSON stringify"}}
A.dr.prototype={
a1(a,b){var t=A.lb(a,this.gck().a)
return t},
K(a,b){var t=A.kp(a,this.gcl().b,null)
return t},
gcl(){return B.aZ},
gck(){return B.aY}}
A.eR.prototype={}
A.eQ.prototype={}
A.fS.prototype={
bm(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.f.a5(a,s,r)
s=r+1
p=A.Y(92)
t.a+=p
p=A.Y(117)
t.a+=p
p=A.Y(100)
t.a+=p
p=q>>>8&15
p=A.Y(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.Y(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.Y(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.f.a5(a,s,r)
s=r+1
p=A.Y(92)
t.a+=p
switch(q){case 8:p=A.Y(98)
t.a+=p
break
case 9:p=A.Y(116)
t.a+=p
break
case 10:p=A.Y(110)
t.a+=p
break
case 12:p=A.Y(102)
t.a+=p
break
case 13:p=A.Y(114)
t.a+=p
break
default:p=A.Y(117)
t.a+=p
p=A.Y(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.Y(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.Y(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.f.a5(a,s,r)
s=r+1
p=A.Y(92)
t.a+=p
p=A.Y(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.f.a5(a,s,n)},
am(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.a(new A.ds(a,null))}B.a.q(t,a)},
ad(a){var t,s,r,q,p=this
if(p.bl(a))return
p.am(a)
try{t=p.b.$1(a)
if(!p.bl(t)){r=A.ic(a,null,p.gb5())
throw A.a(r)}r=p.a
if(0>=r.length)return A.b(r,-1)
r.pop()}catch(q){s=A.hl(q)
r=A.ic(a,s,p.gb5())
throw A.a(r)}},
bl(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.q.m(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.bm(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.am(a)
r.cL(a)
t=r.a
if(0>=t.length)return A.b(t,-1)
t.pop()
return!0}else if(u.I.b(a)){r.am(a)
s=r.cM(a)
t=r.a
if(0>=t.length)return A.b(t,-1)
t.pop()
return s}else return!1},
cL(a){var t,s,r=this.c
r.a+="["
t=J.b_(a)
if(t.gV(a)){this.ad(t.h(a,0))
for(s=1;s<t.gp(a);++s){r.a+=","
this.ad(t.h(a,s))}}r.a+="]"},
cM(a){var t,s,r,q,p,o,n=this,m={}
if(a.gv(a)){n.c.a+="{}"
return!0}t=a.gp(a)*2
s=A.jX(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.T(0,new A.fT(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.bm(A.u(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.b(s,o)
n.ad(s[o])}q.a+="}"
return!0}}
A.fT.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.l(t,s.a++,a)
B.a.l(t,s.a++,b)},
$S:7}
A.fR.prototype={
gb5(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.fK.prototype={
cf(a){var t,s,r,q,p=a.length,o=A.ip(0,null,p)
if(o===0)return new Uint8Array(0)
t=o*3
s=new Uint8Array(t)
r=new A.h_(s)
if(r.bJ(a,0,o)!==o){q=o-1
if(!(q>=0&&q<p))return A.b(a,q)
r.aC()}return new Uint8Array(s.subarray(0,A.kM(0,r.b,t)))}}
A.h_.prototype={
aC(){var t,s=this,r=s.c,q=s.b,p=s.b=q+1
r.$flags&2&&A.J(r)
t=r.length
if(!(q<t))return A.b(r,q)
r[q]=239
q=s.b=p+1
if(!(p<t))return A.b(r,p)
r[p]=191
s.b=q+1
if(!(q<t))return A.b(r,q)
r[q]=189},
c8(a,b){var t,s,r,q,p,o=this
if((b&64512)===56320){t=65536+((a&1023)<<10)|b&1023
s=o.c
r=o.b
q=o.b=r+1
s.$flags&2&&A.J(s)
p=s.length
if(!(r<p))return A.b(s,r)
s[r]=t>>>18|240
r=o.b=q+1
if(!(q<p))return A.b(s,q)
s[q]=t>>>12&63|128
q=o.b=r+1
if(!(r<p))return A.b(s,r)
s[r]=t>>>6&63|128
o.b=q+1
if(!(q<p))return A.b(s,q)
s[q]=t&63|128
return!0}else{o.aC()
return!1}},
bJ(a,b,c){var t,s,r,q,p,o,n,m,l=this
if(b!==c){t=c-1
if(!(t>=0&&t<a.length))return A.b(a,t)
t=(a.charCodeAt(t)&64512)===55296}else t=!1
if(t)--c
for(t=l.c,s=t.$flags|0,r=t.length,q=a.length,p=b;p<c;++p){if(!(p<q))return A.b(a,p)
o=a.charCodeAt(p)
if(o<=127){n=l.b
if(n>=r)break
l.b=n+1
s&2&&A.J(t)
t[n]=o}else{n=o&64512
if(n===55296){if(l.b+4>r)break
n=p+1
if(!(n<q))return A.b(a,n)
if(l.c8(o,a.charCodeAt(n)))p=n}else if(n===56320){if(l.b+3>r)break
l.aC()}else if(o<=2047){n=l.b
m=n+1
if(m>=r)break
l.b=m
s&2&&A.J(t)
if(!(n<r))return A.b(t,n)
t[n]=o>>>6|192
l.b=m+1
t[m]=o&63|128}else{n=l.b
if(n+2>=r)break
m=l.b=n+1
s&2&&A.J(t)
if(!(n<r))return A.b(t,n)
t[n]=o>>>12|224
n=l.b=m+1
if(!(m<r))return A.b(t,m)
t[m]=o>>>6&63|128
l.b=n+1
if(!(n<r))return A.b(t,n)
t[n]=o&63|128}}}return p}}
A.L.prototype={
L(a){var t,s,r=this,q=r.c
if(q===0)return r
t=!r.a
s=r.b
q=A.X(q,s)
return new A.L(q===0?!1:t,s,q)},
bH(a){var t,s,r,q,p,o,n,m=this.c
if(m===0)return $.ac()
t=m+a
s=this.b
r=new Uint16Array(t)
for(q=m-1,p=s.length;q>=0;--q){o=q+a
if(!(q<p))return A.b(s,q)
n=s[q]
if(!(o>=0&&o<t))return A.b(r,o)
r[o]=n}p=this.a
o=A.X(t,r)
return new A.L(o===0?!1:p,r,o)},
bI(a){var t,s,r,q,p,o,n,m,l=this,k=l.c
if(k===0)return $.ac()
t=k-a
if(t<=0)return l.a?$.hW():$.ac()
s=l.b
r=new Uint16Array(t)
for(q=s.length,p=a;p<k;++p){o=p-a
if(!(p>=0&&p<q))return A.b(s,p)
n=s[p]
if(!(o<t))return A.b(r,o)
r[o]=n}o=l.a
n=A.X(t,r)
m=new A.L(n===0?!1:o,r,n)
if(o)for(p=0;p<a;++p){if(!(p<q))return A.b(s,p)
if(s[p]!==0)return m.a9(0,$.aA())}return m},
X(a,b){var t,s,r,q,p,o=this
if(b<0)throw A.a(A.bB("shift-amount must be posititve "+b))
t=o.c
if(t===0)return o
s=B.b.A(b,16)
if(B.b.O(b,16)===0)return o.bH(s)
r=t+s+1
q=new Uint16Array(r)
A.iC(o.b,t,b,q)
t=o.a
p=A.X(r,q)
return new A.L(p===0?!1:t,q,p)},
aT(a,b){var t,s,r,q,p,o,n,m,l,k=this
if(b<0)throw A.a(A.bB("shift-amount must be posititve "+b))
t=k.c
if(t===0)return k
s=B.b.A(b,16)
r=B.b.O(b,16)
if(r===0)return k.bI(s)
q=t-s
if(q<=0)return k.a?$.hW():$.ac()
p=k.b
o=new Uint16Array(q)
A.km(p,t,b,o)
t=k.a
n=A.X(q,o)
m=new A.L(n===0?!1:t,o,n)
if(t){t=p.length
if(!(s>=0&&s<t))return A.b(p,s)
if((p[s]&B.b.X(1,r)-1)!==0)return m.a9(0,$.aA())
for(l=0;l<s;++l){if(!(l<t))return A.b(p,l)
if(p[l]!==0)return m.a9(0,$.aA())}}return m},
Y(a,b){var t,s
u.v.a(b)
t=this.a
if(t===b.a){s=A.fL(this.b,this.c,b.b,b.c)
return t?0-s:s}return t?-1:1},
a6(a,b){var t,s,r,q=this,p=q.c,o=a.c
if(p<o)return a.a6(q,b)
if(p===0)return $.ac()
if(o===0)return q.a===b?q:q.L(0)
t=p+1
s=new Uint16Array(t)
A.kh(q.b,p,a.b,o,s)
r=A.X(t,s)
return new A.L(r===0?!1:b,s,r)},
P(a,b){var t,s,r,q=this,p=q.c
if(p===0)return $.ac()
t=a.c
if(t===0)return q.a===b?q:q.L(0)
s=new Uint16Array(p)
A.dX(q.b,p,a.b,t,s)
r=A.X(p,s)
return new A.L(r===0?!1:b,s,r)},
bt(a,b){var t,s,r,q,p,o,n,m,l=this.c,k=a.c
l=l<k?l:k
t=this.b
s=a.b
r=new Uint16Array(l)
for(q=t.length,p=s.length,o=0;o<l;++o){if(!(o<q))return A.b(t,o)
n=t[o]
if(!(o<p))return A.b(s,o)
m=s[o]
if(!(o<l))return A.b(r,o)
r[o]=n&m}q=A.X(l,r)
return new A.L(!1,r,q)},
bs(a,b){var t,s,r,q,p,o=this.c,n=this.b,m=a.b,l=new Uint16Array(o),k=a.c
if(o<k)k=o
for(t=n.length,s=m.length,r=0;r<k;++r){if(!(r<t))return A.b(n,r)
q=n[r]
if(!(r<s))return A.b(m,r)
p=m[r]
if(!(r<o))return A.b(l,r)
l[r]=q&~p}for(r=k;r<o;++r){if(!(r>=0&&r<t))return A.b(n,r)
s=n[r]
if(!(r<o))return A.b(l,r)
l[r]=s}t=A.X(o,l)
return new A.L(!1,l,t)},
bu(a,b){var t,s,r,q,p,o,n,m,l=this.c,k=a.c,j=l>k?l:k,i=this.b,h=a.b,g=new Uint16Array(j)
if(l<k){t=l
s=a}else{t=k
s=this}for(r=i.length,q=h.length,p=0;p<t;++p){if(!(p<r))return A.b(i,p)
o=i[p]
if(!(p<q))return A.b(h,p)
n=h[p]
if(!(p<j))return A.b(g,p)
g[p]=o|n}m=s.b
for(r=m.length,p=t;p<j;++p){if(!(p>=0&&p<r))return A.b(m,p)
q=m[p]
if(!(p<j))return A.b(g,p)
g[p]=q}r=A.X(j,g)
return new A.L(r!==0,g,r)},
ak(a,b){var t,s,r,q,p,o,n,m,l=this.c,k=a.c,j=l>k?l:k,i=this.b,h=a.b,g=new Uint16Array(j)
if(l<k){t=l
s=a}else{t=k
s=this}for(r=i.length,q=h.length,p=0;p<t;++p){if(!(p<r))return A.b(i,p)
o=i[p]
if(!(p<q))return A.b(h,p)
n=h[p]
if(!(p<j))return A.b(g,p)
g[p]=o^n}m=s.b
for(r=m.length,p=t;p<j;++p){if(!(p>=0&&p<r))return A.b(m,p)
q=m[p]
if(!(p<j))return A.b(g,p)
g[p]=q}r=A.X(j,g)
return new A.L(r===0?!1:b,g,r)},
bn(a,b){var t,s,r,q=this
u.v.a(b)
if(q.c===0||b.c===0)return $.ac()
t=q.a
if(t===b.a){if(t){t=$.aA()
return q.P(t,!0).bu(b.P(t,!0),!0).a6(t,!0)}return q.bt(b,!1)}if(t){s=q
r=b}else{s=b
r=q}return r.bs(s.P($.aA(),!1),!1)},
br(a,b){var t,s,r,q=this
if(q.c===0)return b
if(b.c===0)return q
t=q.a
if(t===b.a){if(t){t=$.aA()
return q.P(t,!0).ak(b.P(t,!0),!1)}return q.ak(b,!1)}if(t){s=q
r=b}else{s=b
r=q}t=$.aA()
return r.ak(s.P(t,!0),!0).a6(t,!0)},
aS(a,b){var t,s,r=this,q=r.c
if(q===0)return b
t=b.c
if(t===0)return r
s=r.a
if(s===b.a)return r.a6(b,s)
if(A.fL(r.b,q,b.b,t)>=0)return r.P(b,s)
return b.P(r,!s)},
a9(a,b){var t,s,r=this,q=r.c
if(q===0)return b.L(0)
t=b.c
if(t===0)return r
s=r.a
if(s!==b.a)return r.a6(b,s)
if(A.fL(r.b,q,b.b,t)>=0)return r.P(b,s)
return b.P(r,!s)},
a3(a,b){var t,s,r,q,p,o,n,m=this.c,l=b.c
if(m===0||l===0)return $.ac()
t=m+l
s=this.b
r=b.b
q=new Uint16Array(t)
for(p=r.length,o=0;o<l;){if(!(o<p))return A.b(r,o)
A.iD(r[o],s,0,q,o,m);++o}p=this.a!==b.a
n=A.X(t,q)
return new A.L(n===0?!1:p,q,n)},
b_(a){var t,s,r,q
if(this.c<a.c)return $.ac()
this.b0(a)
t=$.hB.M()-$.cH.M()
s=A.hD($.hA.M(),$.cH.M(),$.hB.M(),t)
r=A.X(t,s)
q=new A.L(!1,s,r)
return this.a!==a.a&&r>0?q.L(0):q},
b7(a){var t,s,r,q=this
if(q.c<a.c)return q
q.b0(a)
t=A.hD($.hA.M(),0,$.cH.M(),$.cH.M())
s=A.X($.cH.M(),t)
r=new A.L(!1,t,s)
if($.hC.M()>0)r=r.aT(0,$.hC.M())
return q.a&&r.c>0?r.L(0):r},
b0(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=d.c
if(c===$.iz&&a.c===$.iB&&d.b===$.iy&&a.b===$.iA)return
t=a.b
s=a.c
r=s-1
if(!(r>=0&&r<t.length))return A.b(t,r)
q=16-B.b.gbg(t[r])
if(q>0){p=new Uint16Array(s+5)
o=A.ix(t,s,q,p)
n=new Uint16Array(c+5)
m=A.ix(d.b,c,q,n)}else{n=A.hD(d.b,0,c,c+2)
o=s
p=t
m=c}r=o-1
if(!(r>=0&&r<p.length))return A.b(p,r)
l=p[r]
k=m-o
j=new Uint16Array(m)
i=A.hF(p,o,k,j)
h=m+1
r=n.$flags|0
if(A.fL(n,m,j,i)>=0){r&2&&A.J(n)
if(!(m>=0&&m<n.length))return A.b(n,m)
n[m]=1
A.dX(n,h,j,i,n)}else{r&2&&A.J(n)
if(!(m>=0&&m<n.length))return A.b(n,m)
n[m]=0}r=o+2
g=new Uint16Array(r)
if(!(o>=0&&o<r))return A.b(g,o)
g[o]=1
A.dX(g,o+1,p,o,g)
f=m-1
for(r=n.length;k>0;){e=A.ki(l,n,f);--k
A.iD(e,g,0,n,k,o)
if(!(f>=0&&f<r))return A.b(n,f)
if(n[f]<e){i=A.hF(g,o,k,j)
A.dX(n,h,j,i,n)
while(--e,n[f]<e)A.dX(n,h,j,i,n)}--f}$.iy=d.b
$.iz=c
$.iA=t
$.iB=s
$.hA.b=n
$.hB.b=h
$.cH.b=o
$.hC.b=q},
gD(a){var t,s,r,q,p=new A.fM(),o=this.c
if(o===0)return 6707
t=this.a?83585:429689
for(s=this.b,r=s.length,q=0;q<o;++q){if(!(q<r))return A.b(s,q)
t=p.$2(t,s[q])}return new A.fN().$1(t)},
a_(a,b){if(b==null)return!1
return b instanceof A.L&&this.Y(0,b)===0},
aO(a){var t,s,r,q
for(t=this.c-1,s=this.b,r=s.length,q=0;t>=0;--t){if(!(t<r))return A.b(s,t)
q=q*65536+s[t]}return this.a?-q:q},
m(a){var t,s,r,q,p,o=this,n=o.c
if(n===0)return"0"
if(n===1){if(o.a){n=o.b
if(0>=n.length)return A.b(n,0)
return B.b.m(-n[0])}n=o.b
if(0>=n.length)return A.b(n,0)
return B.b.m(n[0])}t=A.j([],u.s)
n=o.a
s=n?o.L(0):o
while(s.c>1){r=$.hV()
if(r.c===0)A.i(B.y)
q=s.b7(r).m(0)
B.a.q(t,q)
p=q.length
if(p===1)B.a.q(t,"000")
if(p===2)B.a.q(t,"00")
if(p===3)B.a.q(t,"0")
s=s.b_(r)}r=s.b
if(0>=r.length)return A.b(r,0)
B.a.q(t,B.b.m(r[0]))
if(n)B.a.q(t,"-")
return new A.aP(t,u.bJ).cw(0)},
aB(a){if(a<10)return 48+a
return 97+a-10},
aP(a,b){var t,s,r,q,p,o,n,m=this
if(b<2||b>36)throw A.a(A.ap(b,2,36,null,null))
t=m.c
if(t===0)return"0"
if(t===1){t=m.b
if(0>=t.length)return A.b(t,0)
s=B.b.aP(t[0],b)
if(m.a)return"-"+s
return s}if(b===16)return m.c1()
r=A.aT(b)
q=A.j([],u.t)
t=m.a
p=t?m.L(0):m
for(o=r.c===0;p.c!==0;){if(o)A.i(B.y)
n=p.b7(r).aO(0)
p=p.b_(r)
B.a.q(q,m.aB(n))}s=A.it(new A.aP(q,u.B))
if(t)return"-"+s
return s},
c1(){var t,s,r,q,p,o,n,m=this,l=A.j([],u.t)
for(t=m.c-1,s=m.b,r=s.length,q=0;q<t;++q){if(!(q<r))return A.b(s,q)
p=s[q]
for(o=0;o<4;++o){B.a.q(l,m.aB(p&15))
p=p>>>4}}if(!(t>=0&&t<r))return A.b(s,t)
n=s[t]
while(n!==0){B.a.q(l,m.aB(n&15))
n=n>>>4}if(m.a)B.a.q(l,45)
return A.it(new A.aP(l,u.B))},
$ia9:1}
A.fM.prototype={
$2(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
$S:8}
A.fN.prototype={
$1(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
$S:41}
A.ew.prototype={
$0(){var t=this
return A.i(A.bB("("+t.a+", "+t.b+", "+t.c+", "+t.d+", "+t.e+", "+t.f+", "+t.r+", "+t.w+")"))},
$S:38}
A.aD.prototype={
al(a){var t=1000,s=B.b.O(a,t),r=B.b.A(a-s,t),q=this.b+s,p=B.b.O(q,t),o=this.c
return new A.aD(A.i6(this.a+B.b.A(q-p,t)+r,p,o),p,o)},
a_(a,b){if(b==null)return!1
return b instanceof A.aD&&this.a===b.a&&this.b===b.b&&this.c===b.c},
gD(a){return A.k0(this.a,this.b)},
Y(a,b){var t
u.dy.a(b)
t=B.b.Y(this.a,b.a)
if(t!==0)return t
return B.b.Y(this.b,b.b)},
m(a){var t=this,s=A.i5(A.bj(t)),r=A.aE(A.dI(t)),q=A.aE(A.dH(t)),p=A.aE(A.ij(t)),o=A.aE(A.il(t)),n=A.aE(A.im(t)),m=A.ex(A.ik(t)),l=t.b,k=l===0?"":A.ex(l)
l=s+"-"+r
if(t.c)return l+"-"+q+" "+p+":"+o+":"+n+"."+m+k+"Z"
else return l+"-"+q+" "+p+":"+o+":"+n+"."+m+k},
cI(){var t=this,s=A.bj(t)>=-9999&&A.bj(t)<=9999?A.i5(A.bj(t)):A.jH(A.bj(t)),r=A.aE(A.dI(t)),q=A.aE(A.dH(t)),p=A.aE(A.ij(t)),o=A.aE(A.il(t)),n=A.aE(A.im(t)),m=A.ex(A.ik(t)),l=t.b,k=l===0?"":A.ex(l)
l=s+"-"+r
if(t.c)return l+"-"+q+"T"+p+":"+o+":"+n+"."+m+k+"Z"
else return l+"-"+q+"T"+p+":"+o+":"+n+"."+m+k},
$ia9:1}
A.ey.prototype={
$1(a){if(a==null)return 0
return A.e8(a)},
$S:13}
A.ez.prototype={
$1(a){var t,s,r
if(a==null)return 0
for(t=a.length,s=0,r=0;r<6;++r){s*=10
if(r<t){if(!(r<t))return A.b(a,r)
s+=a.charCodeAt(r)^48}}return s},
$S:13}
A.e0.prototype={
m(a){return this.R()},
$iau:1}
A.F.prototype={}
A.d0.prototype={
m(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.dc(t)
return"Assertion failed"}}
A.cC.prototype={}
A.at.prototype={
gap(){return"Invalid argument"+(!this.a?"(s)":"")},
gao(){return""},
m(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.gap()+r+p
if(!t.a)return o
return o+t.gao()+": "+A.dc(t.gaK())},
gaK(){return this.b}}
A.cx.prototype={
gaK(){return A.e6(this.b)},
gap(){return"RangeError"},
gao(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.A(r):""
else if(r==null)t=": Not greater than or equal to "+A.A(s)
else if(r>s)t=": Not in inclusive range "+A.A(s)+".."+A.A(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.A(s)
return t}}
A.di.prototype={
gaK(){return A.E(this.b)},
gap(){return"RangeError"},
gao(){if(A.E(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gp(a){return this.f}}
A.cF.prototype={
m(a){return"Unsupported operation: "+this.a}}
A.dU.prototype={
m(a){return"UnimplementedError: "+this.a}}
A.bR.prototype={
m(a){return"Bad state: "+this.a}}
A.d8.prototype={
m(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.dc(t)+"."}}
A.dD.prototype={
m(a){return"Out of Memory"},
$iF:1}
A.cB.prototype={
m(a){return"Stack Overflow"},
$iF:1}
A.fP.prototype={
m(a){return"Exception: "+this.a}}
A.ai.prototype={
m(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException",r=this.b
if(typeof r=="string"){if(r.length>78)r=B.f.a5(r,0,75)+"..."
return s+"\n"+r}else return s}}
A.dj.prototype={
m(a){return"IntegerDivisionByZeroException"},
$iF:1}
A.h.prototype={
ac(a,b){return A.i3(this,A.k(this).i("h.E"),b)},
a8(a,b,c){var t=A.k(this)
return A.jY(this,t.u(c).i("1(h.E)").a(b),t.i("h.E"),c)},
N(a,b){var t
A.k(this).i("o(h.E)").a(b)
for(t=this.gn(this);t.j();)if(b.$1(t.gk()))return!0
return!1},
W(a){return A.dt(this,A.k(this).i("h.E"))},
gp(a){var t,s=this.gn(this)
for(t=0;s.j();)++t
return t},
gv(a){return!this.gn(this).j()},
gV(a){return!this.gv(this)},
C(a,b){var t,s
A.hw(b,"index")
t=this.gn(this)
for(s=b;t.j();){if(s===0)return t.gk();--s}throw A.a(A.hq(b,b-s,this,"index"))},
m(a){return A.jN(this,"(",")")}}
A.R.prototype={
m(a){return"MapEntry("+A.A(this.a)+": "+A.A(this.b)+")"}}
A.cv.prototype={
gD(a){return A.e.prototype.gD.call(this,0)},
m(a){return"null"}}
A.e.prototype={$ie:1,
a_(a,b){return this===b},
gD(a){return A.dJ(this)},
m(a){return"Instance of '"+A.dK(this)+"'"},
gF(a){return A.lw(this)},
toString(){return this.m(this)}}
A.bS.prototype={
gp(a){return this.a.length},
m(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$ik9:1}
A.dF.prototype={}
A.bO.prototype={}
A.ea.prototype={}
A.eg.prototype={
cE(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=a.r,e=a.w
if(f.length===0===(e.length===0))throw A.a(B.aO)
t=a.e
if(t.length===0)throw A.a(B.aJ)
s=A.C(u.N,u.cH)
for(r=a.f,q=r.length,p=0;p<r.length;r.length===q||(0,A.v)(r),++p){o=r[p]
n=o.a
m=n.a+"@"+n.b
if(s.G(m))throw A.a(A.f("Duplicate component reference "+m+".",null))
s.l(0,m,o)}if(e.length===0){e=A.j([],u.k)
for(r=f.length,p=0;p<f.length;f.length===r||(0,A.v)(f),++p){l=f[p]
e.push(new A.bD(l.a,l.b))}k=e}else k=B.a_.cq(0,e)
f=A.j([],u.s)
for(e=t.length,p=0;p<t.length;t.length===e||(0,A.v)(t),++p)f.push(t[p].a)
e=A.j([],u.gI)
for(r=k.length,q=u.dP,p=0;p<k.length;k.length===r||(0,A.v)(k),++p){l=k[p]
n=A.j([],q)
for(j=t.length,i=l.e,h=0;h<t.length;t.length===j||(0,A.v)(t),++h){g=t[h]
n.push(new A.bm(g.a,this.bz(g,i,s)))}e.push(new A.dW(l.a,n))}return new A.cy(a.a,a.b,a.c,f,e)},
bz(a,b,c){var t,s,r,q,p,o,n,m,l,k,j,i,h,g
u.g1.a(b)
u.bv.a(c)
t=A.j([],u.L)
for(s=b.length,r=B.a.gcd(a.b),q=a.a,p=u.s,o=0;o<b.length;b.length===s||(0,A.v)(b),++o){n=b[o]
m=c.h(0,n.a+"@"+n.b)
if(m==null)throw A.a(A.f("Unknown component reference "+this.bM(n)+".",null))
l=m.c
if(l.length!==0&&!B.a.H(l,q))continue
l=m.d
if(l.length===0){l=m.b.d
k=l==null?A.j([q],p):A.j([l],p)}else{j=A.y(l)
i=j.i("aa<1>")
l=A.D(new A.aa(l,j.i("o(1)").a(r),i),i.i("h.E"))
l.$flags=1
k=l}for(l=k.length,j=m.b,i=j.a,h=j.b,j=j.c,g=0;g<k.length;k.length===l||(0,A.v)(k),++g)B.a.q(t,new A.aB(i,h,j,k[g]))}return A.eW(t,u.n)},
bM(a){return a.a+"@"+a.b}}
A.am.prototype={}
A.b4.prototype={}
A.aJ.prototype={}
A.bD.prototype={}
A.fz.prototype={
cq(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h
u.ao.a(b)
t=A.j([],u.k)
for(s=b.length,r=u.h,q=0;q<b.length;b.length===s||(0,A.v)(b),++q){p=b[q]
for(o=p.b,n=p.c,m=1;m<=o;++m)for(l=n.length,k=0;k<n.length;n.length===l||(0,A.v)(n),++k){j=n[k]
i=t.length
h=A.eV(j.b,!1,r)
h.$flags=3
B.a.q(t,new A.bD(i+1,h))}}return A.eW(t,u.aU)}}
A.eA.prototype={
bi(a,b){if(b<=0)throw A.a(B.aq)
return new A.x(B.b.A(a.a*(30+b)+15,30),a.b)}}
A.fH.prototype={
cF(a,b){var t,s,r,q,p,o,n=null,m=b.a
if(m<=0||m>1e4)A.i(A.c9(B.C,"Training-max ratio must be greater than 0% and at most 100%."))
A:{t=a instanceof A.bM
s=n
r=n
if(t){s=a.a
r=s}if(t){q=r
break A}t=a instanceof A.bQ
p=n
o=n
if(t){s=a.a
p=a.b
o=a.c
r=s}else r=n
if(t){if(o.toLowerCase()!=="epley")throw A.a(A.c9(B.p,"Unsupported rep-max formula: "+A.A(o)+"."))
q=B.x.bi(r,p)
break A}t=a instanceof A.b5
if(t)r=a.a
else r=n
if(t)return r
q=n}return new A.x(B.b.A(q.a*m+5000,1e4),q.b)}}
A.eX.prototype={
aN(a,b){return new A.x(B.b.A(a.a*b.a+5000,1e4),a.b)}}
A.dG.prototype={}
A.fA.prototype={
bo(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=a.b
this.c5(e,b)
t=a.a
s=b.a
r=s.a
q=B.b.A(t-r,2)
if(q<0)return new A.dG(s,B.J,B.aU)
p=Math.abs(q)
o=b.b
for(s=o.length,n=B.b.az(1,s),m=0,l=0,k=0;k<n;++k){for(j=0,i=0;i<s;++i)if((k&B.b.az(1,i))>>>0!==0)j+=o[i].a
h=Math.abs(q-j)
if(h>=p)g=h===p&&j<m
else g=!0
if(g){l=k
p=h
m=j}}s=A.j([],u.c)
for(i=0;i<o.length;++i)if((l&B.b.az(1,i))>>>0!==0)s.push(o[i])
B.a.aU(s,new A.fC())
n=r+2*m
g=B.a.bk(o,0,new A.fD(),u.S)
if(n===t)f=null
else f=t>r+2*g?B.aT:B.aS
return new A.dG(new A.x(n,e),A.eW(s,u.W),f)},
c5(a,b){if(b.a.b!==a||B.a.N(b.b,new A.fB(a)))throw A.a(B.ap)}}
A.fC.prototype={
$2(a,b){var t=u.W
t.a(a)
return B.b.Y(t.a(b).a,a.a)},
$S:34}
A.fD.prototype={
$2(a,b){return A.E(a)+u.W.a(b).a},
$S:28}
A.fB.prototype={
$1(a){u.W.a(a)
return a.b!==this.a||a.a<=0},
$S:27}
A.da.prototype={
bh(a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=this
a5.c2(a6,a7)
t=a5.b9(a6,a7)
s=u.N
r=u.W
q=A.C(s,r)
for(p=A.fU(t,t.r,A.k(t).c),o=a7.y,n=a7.r,m=a7.e,l=p.$ti.c,k=a7.f;p.j();){j=p.d
if(j==null)j=l.a(j)
i=m.h(0,j)
if(i==null)throw A.a(A.c9(B.i,"No maximum was supplied for "+j+"."))
h=n.h(0,j)
g=B.a3.cF(i,h==null?k:h)
if(g.b!==o)throw A.a(A.c9(B.D,"Maximum for "+j+" does not use "+o.b+"."))
q.l(0,j,g)}p=a7.b
f=A.hp(A.bj(p),A.dI(p),A.dH(p))
e=A.j([],u.gF)
for(p=a6.e,o=p.length,n=a7.d,m=a7.c,l=a7.a,j=l+"-w",d=u.d_,c=0;c<p.length;p.length===o||(0,A.v)(p),++c){b=p[c]
a=A.j([],d)
for(a0=b.a,a1=j+a0+"-s",a2=0;a2<n.length;){a3=n[a2]
if(!(a2<m.length))return A.b(m,a2)
f=f.al(864e8*B.b.O(m[a2]-A.k1(f)+7,7));++a2
B.a.q(a,new A.ba(a1+a2,f,a3,a5.bB(a5.aZ(b,a3),a3,q,a7)))
f=f.al(864e8)}B.a.q(e,new A.bc(a0,a))}s=A.C(s,r)
for(r=new A.a7(q,q.$ti.i("a7<1,2>")).gn(0);r.j();){a4=r.d
s.l(0,a4.a,a4.b)}return new A.eG(l,a6.a,a6.b,a6.c,s,e)},
bB(a,b,c,d){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
u.z.a(a)
u.p.a(c)
t=A.j([],u.fR)
for(s=a.length,r=!d.as,q=d.e,p=u.cm,o=0;o<s;++o){n=a[o]
if(!r||n.b!=="deload"){m=n.d
l=m==null
k=l?b:m
j=A.j([],p)
for(i=n.c,h=0;h<i.length;++h){g=i[h]
f=l?b:m
e=c.h(0,l?b:m)
j.push(this.bC(h,g,a,f,e,q.h(0,l?b:m),d))}t.push(new A.b9(n.a,n.b,j,k))}}return t},
bC(a,a0,a1,a2,a3,a4,a5){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=null
u.z.a(a1)
t=a0.b
A:{s=t instanceof A.bo
r=b
q=b
if(s){r=t.a
q=r}p=b
o=b
if(s){if(a3==null)throw A.a(B.ae)
o=q.a
p=B.n.aN(a3,q)
break A}s=t instanceof A.bN
if(s)q=t.a
else q=b
if(s){if(a4==null)throw A.a(B.ag)
o=q.a
p=B.n.aN(this.bP(a4),q)
break A}if(t instanceof A.c3||t instanceof A.cD)break A
n=t instanceof A.bP
if(n){m=t.a
l=t.b}else{l=b
m=l}if(n){if(a3==null)throw A.a(B.ah)
k=this.bU(a1,a2,m,a5)
if(typeof l!=="number")return A.ly(l)
o=B.b.A(k.a*l+5000,1e4)
p=B.n.aN(a3,new A.W(o))}}if(p!=null){n=a5.z
j=n.a
if(j<=0)A.i(B.E)
i=p.b
if(n.b!==i)A.i(B.ad)
h=B.a0.bo(new A.x(B.b.aV(p.a+B.b.A(j,2),j)*j,i),a5.Q)}else h=b
n=a0.a.t()
j=h==null
i=j?b:h.a
g=j?b:h.b
if(g==null)g=B.J
f=A.j([],u.e3)
for(e=0;!1;++e){d=B.b7[e]
c=d.gcQ()
f.push(new A.bl(c,d.gcR()?B.ch:B.ci))}return new A.bb(a,n,o,i,g,B.a1,f,j?b:h.c)},
bU(a,b,c,d){var t,s,r,q,p,o
u.z.a(a)
t=A.y(a)
s=t.i("aa<1>")
t=A.D(new A.aa(a,t.i("o(1)").a(new A.es(b)),s),s.i("h.E"))
t.$flags=1
r=t
t=r.length
if(t===0)throw A.a(B.ai)
if(t>1)throw A.a(B.ar)
q=B.a.gai(r).c
switch(c.a){case 0:t=0
break
case 1:t=q.length<2?null:1
break
case 2:t=q.length-1
break
default:t=null}if(t==null||q.length===0)throw A.a(B.as)
if(t>>>0!==t||t>=q.length)return A.b(q,t)
p=q[t].b
A:{if(p instanceof A.bo){o=p.a
t=o
break A}t=A.i(B.al)}return t},
bP(a){var t,s,r,q,p=null,o=a instanceof A.bM
if(o)t=a.a
else t=p
if(o)return t
o=a instanceof A.bQ
s=p
r=p
if(o){q=a.a
s=a.b
r=a.c
t=q}else t=p
if(o){if(r.toLowerCase()!=="epley")throw A.a(A.c9(B.p,"Unsupported rep-max formula: "+A.A(r)+"."))
return B.x.bi(t,s)}if(a instanceof A.b5)throw A.a(B.ao)},
c2(a,b){var t,s,r,q,p
if(B.f.cJ(b.a).length===0)throw A.a(B.aj)
t=b.c
s=t.length
r=b.d
if(s!==r.length||s===0||B.a.N(t,new A.eu()))throw A.a(B.af)
if(A.eU(t,A.y(t).c).a!==t.length)throw A.a(B.ak)
t=a.d
q=A.eU(t,A.y(t).c)
if(r.length===t.length){t=A.y(r).c
t=A.eU(r,t).a!==q.a||!A.eU(r,t).ce(q)}else t=!0
if(t)throw A.a(B.an)
for(t=this.b9(a,b),t=A.fU(t,t.r,A.k(t).c),s=b.e,r=t.$ti.c;t.j();){p=t.d
if(p==null)p=r.a(p)
if(!s.G(p))throw A.a(A.c9(B.i,"No maximum was supplied for "+p+"."))}if(b.z.a<=0)throw A.a(B.E)
t=A.j([b.f],u.eX)
s=b.r
B.a.J(t,new A.bf(s,A.k(s).i("bf<2>")))
if(B.a.N(t,new A.ev()))throw A.a(B.am)},
aZ(a,b){var t=a.c
if(t.length===0)return B.b8
return B.a.I(t,new A.er(b)).c},
b9(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=A.jV(u.N)
for(t=a.e,s=t.length,r=b.d,q=0;q<t.length;t.length===s||(0,A.v)(t),++q){p=t[q]
for(o=r.length,n=0;n<r.length;r.length===o||(0,A.v)(r),++n){m=r[n]
for(l=this.aZ(p,m),k=l.length,j=0;j<k;++j){i=l[j]
if(B.a.N(i.c,new A.et())){h=i.d
g.q(0,h==null?m:h)}}}}return g},
$ijF:1}
A.es.prototype={
$1(a){var t
u.n.a(a)
if(B.cC.H(0,a.b)){t=a.d
t=t==null||t===this.a}else t=!1
return t},
$S:26}
A.eu.prototype={
$1(a){A.E(a)
return a<1||a>7},
$S:17}
A.ev.prototype={
$1(a){var t=u.A.a(a).a
return t<=0||t>1e4},
$S:15}
A.er.prototype={
$1(a){return u.dm.a(a).a===this.a},
$S:16}
A.et.prototype={
$1(a){var t=u.q.a(a).b
return t instanceof A.bo||t instanceof A.bN||t instanceof A.bP},
$S:53}
A.bq.prototype={
R(){return"WeightUnit."+this.b}}
A.x.prototype={
t(){return A.G(["centiUnits",this.a,"unit",this.b.b],u.N,u.K)}}
A.W.prototype={}
A.bn.prototype={}
A.bM.prototype={}
A.bQ.prototype={}
A.b5.prototype={}
A.bk.prototype={}
A.dd.prototype={
t(){return A.G(["type","fixed","count",this.a],u.N,u.K)}}
A.dL.prototype={
t(){return A.G(["type","range","minimum",this.a,"maximum",this.b],u.N,u.K)}}
A.dS.prototype={
t(){return A.G(["type","total","total",this.a],u.N,u.K)}}
A.d_.prototype={
t(){var t,s=A.C(u.N,u.K)
s.l(0,"type","amrap")
t=this.a
if(t!=null)s.l(0,"minimum",t)
return s}}
A.aM.prototype={}
A.bo.prototype={}
A.bN.prototype={}
A.c3.prototype={}
A.cD.prototype={}
A.aO.prototype={
R(){return"RelativeSetPosition."+this.b}}
A.bP.prototype={}
A.dO.prototype={
R(){return"SetExecutionKind."+this.b}}
A.fG.prototype={
t(){var t=A.C(u.N,u.X)
t.l(0,"type","straight")
return t}}
A.cz.prototype={
R(){return"RuntimeDecisionStatus."+this.b}}
A.bl.prototype={
t(){return A.G(["type",this.a.b,"status",this.b.b],u.N,u.K)}}
A.aN.prototype={}
A.aB.prototype={}
A.bm.prototype={}
A.dW.prototype={}
A.cy.prototype={}
A.d2.prototype={}
A.db.prototype={}
A.cg.prototype={
R(){return"GenerationWarningCode."+this.b}}
A.cf.prototype={
t(){return A.G(["code",this.a.b,"message",this.b],u.N,u.K)}}
A.bb.prototype={
t(){var t,s,r,q,p,o=this,n=o.d
n=n==null?null:n.t()
t=o.e
s=A.y(t)
r=s.i("I<1,m<d,e>>")
t=A.D(new A.I(t,s.i("m<d,e>(1)").a(new A.eL()),r),r.i("q.E"))
s=o.f.t()
r=o.r
q=A.y(r)
p=q.i("I<1,m<d,e>>")
r=A.D(new A.I(r,q.i("m<d,e>(1)").a(new A.eM()),p),p.i("q.E"))
q=o.w
q=q==null?null:q.t()
return A.G(["index",o.a,"repetitions",o.b,"percentageBasisPoints",o.c,"plannedLoad",n,"platesPerSide",t,"execution",s,"runtimeDecisions",r,"warning",q],u.N,u.X)}}
A.eL.prototype={
$1(a){return u.W.a(a).t()},
$S:18}
A.eM.prototype={
$1(a){return u.cw.a(a).t()},
$S:19}
A.b9.prototype={
t(){var t=this,s=t.c,r=A.y(s),q=r.i("I<1,m<d,e?>>")
s=A.D(new A.I(s,r.i("m<d,e?>(1)").a(new A.eF()),q),q.i("q.E"))
return A.G(["id",t.a,"role",t.b,"movementId",t.d,"sets",s],u.N,u.K)}}
A.eF.prototype={
$1(a){return u.gS.a(a).t()},
$S:20}
A.ba.prototype={
t(){var t=this,s=t.b.cI(),r=t.d,q=A.y(r),p=q.i("I<1,m<d,e>>")
r=A.D(new A.I(r,q.i("m<d,e>(1)").a(new A.eK()),p),p.i("q.E"))
return A.G(["id",t.a,"date",s,"movementId",t.c,"blocks",r],u.N,u.K)}}
A.eK.prototype={
$1(a){return u.fK.a(a).t()},
$S:21}
A.bc.prototype={
t(){var t=this.b,s=A.y(t),r=s.i("I<1,m<d,e>>")
t=A.D(new A.I(t,s.i("m<d,e>(1)").a(new A.eN()),r),r.i("q.E"))
return A.G(["number",this.a,"sessions",t],u.N,u.K)}}
A.eN.prototype={
$1(a){return u.c2.a(a).t()},
$S:22}
A.eG.prototype={
t(){var t=this,s=u.N,r=t.e.cA(0,new A.eH(),s,u.V),q=t.f,p=A.y(q),o=p.i("I<1,m<d,e>>")
q=A.D(new A.I(q,p.i("m<d,e>(1)").a(new A.eI()),o),o.i("q.E"))
return A.G(["schemaVersion",1,"id",t.a,"catalogVersion",t.b,"templateId",t.c,"variantId",t.d,"effectiveTrainingMaxes",r,"weeks",q],s,u.K)}}
A.eH.prototype={
$2(a,b){return new A.R(A.u(a),u.W.a(b).t(),u.ct)},
$S:23}
A.eI.prototype={
$1(a){return u.aC.a(a).t()},
$S:24}
A.a5.prototype={
R(){return"CycleGenerationErrorCode."+this.b}}
A.Q.prototype={
m(a){return"CycleGenerationException("+this.a.b+"): "+this.b}}
A.ah.prototype={
R(){return"ForeverCompositionErrorCode."+this.b}}
A.bE.prototype={
m(a){return"ForeverCompositionException("+this.a.b+"): "+this.b}}
A.eB.prototype={
cc(a,b){var t,s,r,q,p=this.bR(a,b),o=A.j([],u.bC)
for(t=p.length,s=this.b.a,r=0;r<p.length;p.length===t||(0,A.v)(p),++r){q=p[r]
o.push(new A.cP(q,s.$1(q.b.b)))}return this.bD(a,b,o)},
bR(a,b){var t,s,r,q,p,o,n,m,l,k,j
this.c4(a,b)
t=A.j([],u.a5)
for(s=a.f,r=s.length,q=b.f,p=0;p<s.length;s.length===r||(0,A.v)(s),++p)for(o=s[p].b,n=0;n<1;++n){m=o[n]
l=q.h(0,m.a)
if(!l.e)continue
this.c3(m,l.b)
for(k=m.c,j=0;j<k;++j)B.a.q(t,new A.e_(m,l,j))}return t},
bD(b0,b1,b2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9
u.an.a(b2)
for(t=b2.length,s=0;s<t;++s){r=b2[s]
q=r.a.b.b
p=r.b
if(p.b!==q.a||p.c!==q.b)A.i(A.b7(B.ay,"The resolver returned a different Cycle definition."))}t=b1.d
o=A.hp(A.bj(t),A.dI(t),A.dH(t))
t=b1.e
q=u.N
p=u.W
n=A.ho(t,q,p)
m=A.j([],u.gc)
for(l=b2.length,k=b1.r,j=b1.w,i=b1.x,h=this.c,g=b1.a,f=g+"-",e=u.u,d=B.O,s=0;s<b2.length;b2.length===l||(0,A.v)(b2),++s,d=a9,n=a8){c=b2[s]
r=c.a
b=r.a
a=r.b
a0=m.length
a1=b.a
a2=A.C(q,e)
for(a3=n.gB(),a3=a3.gn(a3);a3.j();){a4=a3.gk()
a2.l(0,a4.a,new A.b5(a4.b))}a5=h.bh(c.b,new A.db(f+a1+"-"+(r.c+1),o,a.c,a.d,a2,a.w,a.x,a.f,a.r,k,j,i,a.y))
a6=this.bN(a5)
a7=this.bx(n,d,b.f,k)
a8=a7.a
a9=a7.b
B.a.q(m,new A.ce(a0,a1,b.b,a.b,a5,new A.dT(n,d),a7))
a1=a6.al(864e8)
o=A.hp(A.bj(a1),A.dI(a1),A.dH(a1))}return new A.eJ(g,b0.a,b0.b,B.bd,A.eW(m,u.aK),A.ho(t,q,p),n)},
c4(a,b){var t,s,r,q,p,o,n,m,l,k
if(a.a===b.b)t=b.c.a!==a.b.a
else t=!0
if(t)throw A.a(B.aA)
s=A.C(u.N,u.ez)
for(t=a.f,r=t.length,q=0;q<t.length;t.length===r||(0,A.v)(t),++q)for(p=t[q].b,o=0;o<1;++o){n=p[o]
m=n.a
if(m.length===0||n.c<1||s.G(m))throw A.a(A.b7(B.F,"Invalid or duplicate slot "+m+"."))
s.l(0,m,n)}for(t=b.f,r=new A.be(t,t.r,t.e,A.k(t).i("be<1>"));r.j();){p=r.d
if(!s.G(p))throw A.a(A.b7(B.av,"No slot named "+p+" exists in the definition."))}for(r=new A.a7(s,s.$ti.i("a7<1,2>")).gn(0);r.j();){p=r.d.a
l=t.h(0,p)
if(l==null)throw A.a(A.b7(B.au,"No request was supplied for slot "+p+"."))
m=l.e
if(!m)throw A.a(A.b7(B.aw,"Required slot "+p+" cannot be disabled."))}for(t=b.e,t=new A.a7(t,A.k(t).i("a7<1,2>")).gn(0),r=b.r;t.j();){k=t.d
if(k.b.b!==r)throw A.a(A.b7(B.G,"Training Max "+k.a+" uses a different unit."))}},
c3(a,b){if(!B.a.N(a.e,new A.eC(b)))throw A.a(A.b7(B.ax,b.gcz()+" is not allowed in slot "+a.a+"."))},
bx(a,b,c,d){var t,s=c.a,r=this.aY(u.p.a(a),s,d),q=c.b||s instanceof A.bT
A:{if(s instanceof A.bA){s=s.b
break A}s=b
break A}t=A.ho(r,u.N,u.W)
return new A.dT(t,q?B.N:s)},
aY(a,b,c){var t,s,r,q,p,o
u.p.a(a)
if(b instanceof A.cl)return A.ax(a,u.N,u.W)
if(b instanceof A.bT)return this.aY(a,B.B,c)
if(b instanceof A.bA){t=A.ax(a,u.N,u.W)
for(s=b.a,s=new A.a7(s,A.k(s).i("a7<1,2>")).gn(0);s.j();){r=s.d
q=r.b
if(q.b!==c)throw A.a(B.aC)
p=r.a
o=t.h(0,p)
if(o!=null)t.l(0,p,new A.x(o.a+q.a,c))}return t}throw A.a(B.aB)},
bN(a){var t,s,r,q,p,o,n,m,l,k,j,i
for(t=a.f,s=t.length,r=null,q=0;q<s;++q)for(p=t[q].b,o=p.length,n=0;n<o;++n){m=p[n]
l=!0
if(r!=null){k=m.b
j=k.a
i=r.a
if(j<=i)l=j===i&&k.b>r.b}if(l)r=m.b}if(r==null)throw A.a(A.b7(B.az,"Generated Cycle "+a.a+" contains no session."))
return r}}
A.eC.prototype={
$1(a){var t
u.bV.a(a)
t=this.a
return a.a+"/"+a.b===t.a+"/"+t.b},
$S:25}
A.e_.prototype={}
A.cP.prototype={}
A.de.prototype={
a_(a,b){if(b==null)return!1
return b instanceof A.de&&b.a===this.a},
gD(a){return B.b.gD(this.a)}}
A.an.prototype={
R(){return"ForeverPhaseRole."+this.b}}
A.du.prototype={
R(){return"MacrocycleState."+this.b}}
A.bp.prototype={
R(){return"TrainingMaxValueKind."+this.b}}
A.aw.prototype={
gcz(){return this.a+"/"+this.b}}
A.bU.prototype={}
A.cl.prototype={}
A.bA.prototype={}
A.bT.prototype={}
A.eE.prototype={}
A.cd.prototype={}
A.df.prototype={}
A.fE.prototype={}
A.dg.prototype={}
A.eD.prototype={}
A.dT.prototype={}
A.ce.prototype={}
A.eJ.prototype={}
A.eb.prototype={
cG(a0,a1,a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=this,b="sessionIds",a="movementIds"
u.D.a(a3)
u.dg.a(a1)
if(!B.a.N(a6.c,new A.ed(c,a2)))throw A.a(B.aQ)
t=A.y(a3)
s=t.i("aa<1>")
r=A.D(new A.aa(a3,t.i("o(1)").a(new A.ee(c,a2)),s),s.i("h.E"))
if(r.length!==1)throw A.a(B.aM)
t=B.a.gai(r).b
s=A.y(t)
q=s.i("b6<1,d>")
q=A.dt(new A.b6(t,s.i("h<d>(1)").a(new A.ef()),q),q.i("h.E"))
t=A.D(q,A.k(q).c)
t.$flags=1
p=t
t=a6.f
o=c.ab(t,b)
n=c.ab(t,a)
t=A.j([],u.gt)
for(s=B.a.gai(r).b,q=s.length,m=u.s,l=0;l<s.length;s.length===q||(0,A.v)(s),++l){k=s[l]
j=A.j([],m)
for(i=k.b,h=i.length,g=0;g<i.length;i.length===h||(0,A.v)(i),++g)j.push(i[g])
t.push(new A.dF(k.a,j))}s=A.j([],u.eG)
for(q=a1.length,j=u.N,l=0;l<a1.length;a1.length===q||(0,A.v)(a1),++l){f=a1[l]
i=A.j([],m)
h=f.d
e=A.D(c.ab(h,b),j)
B.a.J(e,o)
d=e.length
g=0
for(;g<e.length;e.length===d||(0,A.v)(e),++g)i.push(e[g])
e=A.j([],m)
h=A.D(J.N(f.c.h(0,"movementRelation"),"sameAsMain")?p:c.ab(h,a),j)
B.a.J(h,n)
d=h.length
g=0
for(;g<h.length;h.length===d||(0,A.v)(h),++g)e.push(h[g])
s.push(new A.bO(f.a,f.b,i,e))}return new A.ea(a0,a5.a,a6.a,a4,t,s,a6.d,a6.e)},
ab(a,b){var t=u.f.a(a).h(0,b)
if(t==null)return B.r
if(!u.j.b(t)||J.jq(t,new A.ec()))throw A.a(A.f(b+" must contain strings.",null))
return J.js(t,u.N)}}
A.ed.prototype={
$1(a){var t
u.h.a(a)
t=this.b
return a.a===t.a&&a.b===t.b},
$S:4}
A.ee.prototype={
$1(a){var t=u.G.a(a).a,s=this.b
return t.a===s.a&&t.b===s.b},
$S:2}
A.ef.prototype={
$1(a){return u.Q.a(a).b},
$S:11}
A.ec.prototype={
$1(a){return typeof a!="string"},
$S:14}
A.aR.prototype={}
A.ay.prototype={}
A.az.prototype={}
A.aS.prototype={}
A.aH.prototype={}
A.d4.prototype={
cg(a){var t="components",s=J.a3(A.al(this.aw(a,t),t),new A.en(this),u.cL)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
return s},
ci(a){var t="schedules",s=J.a3(A.al(this.aw(a,t),t),new A.ep(this),u.G)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
return s},
cj(a){var t="templates",s=J.a3(A.al(this.aw(a,t),t),new A.eq(this),u.R)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
return s},
c7(a){var t,s,r,q,p="weekPlans",o="phases",n="compatibilities",m=A.a0(a,"variant")
A.U(m,B.cH,B.cJ)
if(m.G(p)===m.G(o))throw A.a(B.aP)
t=A.ad(m,"id")
A.a4(m,"revision")
s=J.a3(A.al(m,"scheduleIds"),new A.ej(this),u.h)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
r=m.h(0,p)==null?B.b9:this.be(A.al(m,p))
if(m.h(0,o)==null)q=B.ba
else{q=J.a3(A.al(m,o),new A.ek(this),u.dr)
q=A.D(q,q.$ti.i("q.E"))
q.$flags=1
q=q}return new A.aS(t,s,r,q,A.a0(m.h(0,n),n))},
be(a){var t=J.a3(a,new A.em(this),u.gJ)
t=A.D(t,t.$ti.i("q.E"))
t.$flags=1
return t},
by(a){var t,s,r,q,p="movementId"
u.f.a(a)
A.U(a,B.cr,B.cw)
t=A.ad(a,"id")
s=A.ad(a,"role")
r=a.h(0,p)==null?null:A.ad(a,p)
q=J.a3(A.al(a,"sets"),new A.eh(this),u.q)
q=A.D(q,q.$ti.i("q.E"))
q.$flags=1
return new A.aB(t,s,q,r)},
bW(a){var t="minimum"
u.f.a(a)
switch(A.ad(a,"type")){case"fixed":A.U(a,B.cF,B.e)
return new A.dd(A.a4(a,"count"))
case"range":A.U(a,B.cq,B.e)
return new A.dL(A.a4(a,t),A.a4(a,"maximum"))
case"total":A.U(a,B.cz,B.e)
return new A.dS(A.a4(a,"total"))
case"amrap":A.U(a,B.cy,B.cD)
return new A.d_(a.h(0,t)==null?null:A.a4(a,t))
default:throw A.a(A.f("Unknown repetition type "+A.A(a.h(0,"type"))+".",null))}},
bO(a){var t="basisPoints"
u.f.a(a)
switch(A.ad(a,"type")){case"training_max_percentage":A.U(a,B.M,B.e)
return new A.bo(new A.W(A.a4(a,t)))
case"one_rep_max_percentage":A.U(a,B.M,B.e)
return new A.bN(new A.W(A.a4(a,t)))
case"bodyweight":A.U(a,B.L,B.e)
return B.P
case"unloaded":A.U(a,B.L,B.e)
return B.a4
case"relative_set":A.U(a,B.cE,B.e)
return new A.bP(A.av(B.b0,A.ad(a,"position"),u.ft),A.a4(a,"multiplierBasisPoints"))
default:throw A.a(A.f("Unknown load type "+A.A(a.h(0,"type"))+".",null))}},
aw(a,b){var t=A.a0(B.d.a1(a,null),"root")
A.U(t,A.jW(["schemaVersion","kind",b],u.N),B.e)
if(A.a4(t,"schemaVersion")!==1||A.ad(t,"kind")!==b)throw A.a(A.f("Expected schemaVersion 1 "+b+" document.",null))
return t},
b6(a){u.f.a(a)
A.U(a,B.cl,B.e)
return new A.am(A.ad(a,"id"),A.a4(a,"revision"))}}
A.en.prototype={
$1(a){var t="constraints",s="compatibilities",r=A.a0(a,"component")
A.U(r,B.cj,B.e)
u.f.a(r)
return new A.aR(new A.am(A.ad(r,"id"),A.a4(r,"revision")),this.a.by(A.a0(r.h(0,"block"),"block")),A.a0(r.h(0,t),t),A.a0(r.h(0,s),s))},
$S:30}
A.ep.prototype={
$1(a){var t,s,r,q=A.a0(a,"schedule")
A.U(q,B.cv,B.e)
u.f.a(q)
t=A.ad(q,"id")
s=A.a4(q,"revision")
r=J.a3(A.al(q,"sessions"),new A.eo(),u.Q)
r=A.D(r,r.$ti.i("q.E"))
r.$flags=1
return new A.ay(new A.am(t,s),r)},
$S:31}
A.eo.prototype={
$1(a){var t=A.a0(a,"session")
A.U(t,B.cu,B.e)
return new A.az(A.ad(t,"id"),A.jy(t,"movementIds"))},
$S:32}
A.eq.prototype={
$1(a){var t,s,r=A.a0(a,"template")
A.U(r,B.cK,B.e)
t=A.ad(r,"id")
A.a4(r,"revision")
s=J.a3(A.al(r,"variants"),this.a.gc6(),u.U)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
return new A.aH(t,s)},
$S:33}
A.ej.prototype={
$1(a){return this.a.b6(A.a0(a,"reference"))},
$S:10}
A.ek.prototype={
$1(a){var t=A.a0(a,"phase")
A.U(t,B.cn,B.e)
return new A.aJ(A.ad(t,"id"),A.a4(t,"repeatCount"),this.a.be(A.al(t,"weekPlans")))},
$S:44}
A.em.prototype={
$1(a){var t,s,r=A.a0(a,"weekPlan")
A.U(r,B.cB,B.e)
t=A.a4(r,"weekNumber")
s=J.a3(A.al(r,"componentIds"),new A.el(this.a),u.h)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
return new A.b4(t,s)},
$S:36}
A.el.prototype={
$1(a){return this.a.b6(A.a0(a,"reference"))},
$S:10}
A.eh.prototype={
$1(a){var t,s,r,q="repetitions",p=A.a0(a,"set")
A.U(p,B.co,B.e)
t=A.a0(p.h(0,q),q)
s=A.a0(p.h(0,"load"),"load")
r=this.a
return new A.aN(r.bW(t),r.bO(s))},
$S:37}
A.ei.prototype={
$1(a){return typeof a=="string"?a:A.i(A.f(this.a+" values must be strings.",null))},
$S:5}
A.c4.prototype={
a7(a,b,c){var t
u.dG.a(c)
if(!this.b)A.i(A.dP("ENGINE_NOT_INITIALIZED"))
A.d3(b,a+" request")
t=A.u(c.$1(b))
A.d3(t,a+" response")
return t}}
A.co.prototype={
aH(a9){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=null,b="contentHash",a="templates",a0="optionSchemas",a1="schedules",a2="foreverDefinitions",a3="movements",a4="id",a5="movements must be a list",a6="movement must be an object",a7="id must be a string",a8=A.H(B.d.a1(a9,c),"catalog")
A.aY(a8,B.cI)
t=u.f
s=J.a3(A.aZ(a8,"documents"),new A.fk(),t)
s=A.D(s,s.$ti.i("q.E"))
s.$flags=1
r=s
d.e=A.aX(a8,"catalogVersion")
if(typeof a8.h(0,b)=="string"){s=a8.h(0,b)
s.toString
A.u(s)}else s=A.hM(A.e7(a8))
d.f=s
s=A.j([],u.F)
for(q=A.y(r),p=q.i("o(1)"),o=p.a(new A.fl()),n=B.a.gn(r),q=q.i("Z<1>"),o=new A.Z(n,o,q);o.j();)B.a.J(s,B.m.cj(B.d.K(n.gk(),c)))
d.r=s
s=A.j([],u._)
for(o=p.a(new A.fm()),n=B.a.gn(r),o=new A.Z(n,o,q);o.j();)B.a.J(s,B.m.ci(B.d.K(n.gk(),c)))
d.w=s
s=A.j([],u.E)
for(o=p.a(new A.fn()),n=B.a.gn(r),o=new A.Z(n,o,q);o.j();)B.a.J(s,B.m.cg(B.d.K(n.gk(),c)))
d.x=s
s=u.d
o=A.j([],s)
for(n=p.a(new A.fo()),m=B.a.gn(r),n=new A.Z(m,n,q),l=u.j,k=u.J;n.j();){j=m.gk()
if(l.b(j.h(0,a))){j=j.h(0,a)
j.toString
k.a(j)}else j=A.i(A.f("templates must be a list",c))
j=J.O(j)
while(j.j()){i=j.gk()
o.push(t.b(i)?i:A.i(A.f("template must be an object",c)))}}d.y=o
o=A.j([],s)
for(n=p.a(new A.fp()),m=B.a.gn(r),n=new A.Z(m,n,q);n.j();){j=m.gk()
if(l.b(j.h(0,a0))){j=j.h(0,a0)
j.toString
k.a(j)}else j=A.i(A.f("optionSchemas must be a list",c))
j=J.O(j)
while(j.j()){i=j.gk()
o.push(t.b(i)?i:A.i(A.f("option schema must be an object",c)))}}d.z=o
o=A.j([],s)
for(n=p.a(new A.fq()),m=B.a.gn(r),n=new A.Z(m,n,q);n.j();){j=m.gk()
if(l.b(j.h(0,a1))){j=j.h(0,a1)
j.toString
k.a(j)}else j=A.i(A.f("schedules must be a list",c))
j=J.O(j)
while(j.j()){i=j.gk()
o.push(t.b(i)?i:A.i(A.f("schedule must be an object",c)))}}d.Q=o
s=A.j([],s)
for(o=p.a(new A.fr()),n=B.a.gn(r),o=new A.Z(n,o,q);o.j();){m=n.gk()
if(l.b(m.h(0,a2))){m=m.h(0,a2)
m.toString
k.a(m)}else m=A.i(A.f("foreverDefinitions must be a list",c))
m=J.O(m)
while(m.j()){i=m.gk()
s.push(t.b(i)?i:A.i(A.f("forever definition must be an object",c)))}}d.as=s
s=u.N
o=A.C(s,u.ck)
for(n=p.a(new A.fs()),m=B.a.gn(r),n=new A.Z(m,n,q);n.j();){j=m.gk()
if(l.b(j.h(0,a3))){j=j.h(0,a3)
j.toString
k.a(j)}else j=A.i(A.f(a5,c))
j=J.O(j)
while(j.j()){i=j.gk()
h=t.b(i)?i:A.i(A.f(a6,c))
if(typeof h.h(0,a4)=="string"){h=h.h(0,a4)
h.toString
A.u(h)}else h=A.i(A.f(a7,c))
g=A.C(s,s)
f=i.h(0,"labels")
f=(t.b(f)?f:A.i(A.f("labels must be an object",c))).gB()
f=f.gn(f)
while(f.j()){e=f.gk()
g.l(0,e.a,A.u(e.b))}o.l(0,h,g)}}d.at=o
s=A.C(s,s)
for(p=p.a(new A.ft()),o=B.a.gn(r),q=new A.Z(o,p,q);q.j();){p=o.gk()
if(l.b(p.h(0,a3))){p=p.h(0,a3)
p.toString
k.a(p)}else p=A.i(A.f(a5,c))
p=J.O(p)
while(p.j()){i=p.gk()
n=t.b(i)?i:A.i(A.f(a6,c))
if(typeof n.h(0,a4)=="string"){n=n.h(0,a4)
n.toString
A.u(n)}else n=A.i(A.f(a7,c))
if(typeof i.h(0,"pattern")=="string"){m=i.h(0,"pattern")
m.toString
A.u(m)}else m=A.i(A.f("pattern must be a string",c))
s.l(0,n,m)}}d.ax=s
if(d.r.length===0||d.w.length===0||d.x.length===0)throw A.a(B.aL)
t=d.S()
t.l(0,"initialized",!0)
return B.d.K(t,c)},
aE(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null,b="variants",a=A.H(B.d.a1(a0,c),"request")
A.aY(a,B.ct)
A.h5(a)
t=u.N
s=u.X
r=A.ax(this.S(),t,s)
q=A.j([],u.d)
for(p=this.y,o=p.length,n=u.f,m=u.j,l=u.J,k=0;k<p.length;p.length===o||(0,A.v)(p),++k){j=p[k]
i=j.h(0,"id")
h=j.h(0,"revision")
g=j.h(0,"labels")
f=[]
if(m.b(j.h(0,b))){e=j.h(0,b)
e.toString
l.a(e)}else e=A.i(A.f("variants must be a list",c))
e=J.O(e)
while(e.j()){d=e.gk()
f.push((n.b(d)?d:A.i(A.f("variant must be an object",c))).h(0,"id"))}q.push(A.G(["id",i,"revision",h,"labels",g,"variantIds",f],t,s))}r.l(0,"templates",q)
return B.d.K(r,c)},
aG(c9){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2=this,b3=null,b4="templateId",b5="variantId",b6="variants",b7="validExample",b8="scheduleId",b9="template",c0="choice",c1="labels",c2="scheduling",c3="segmented",c4="weight",c5="plating",c6="output",c7="generate",c8=A.H(B.d.a1(c9,b3),"request")
A.hQ(c8,B.cm)
t=A.T(c8,b4)
s=A.T(c8,b5)
r=B.a.I(b2.y,new A.f8(t))
A.h5(c8)
q=u.f
p=J.a3(A.aZ(r,b6),new A.f9(),q).I(0,new A.fa(s))
o=A.H(p.h(0,"optionSchemaId"),"option schema reference")
n=B.a.I(b2.z,new A.fb(o))
m=q.b(p.h(0,b7))?A.aW(A.H(p.h(0,b7),"example").h(0,b8)):b3
l=B.a.I(B.a.I(b2.r,new A.fc(t)).c,new A.fd(s))
k=A.aW(c8.h(0,b8))
j=k==null?m:k
if(j==null)j=B.a.gZ(l.c).a
i=l.c
if(!B.a.N(i,new A.fe(j)))throw A.a(A.f("SCHEDULE_NOT_ALLOWED:"+j,b3))
h=B.a.cr(b2.w,new A.ff(j))
g=b2.av(t,s,B.r,j)
f=h.b
e=A.y(f)
d=e.i("b6<1,d>")
d=A.dt(new A.b6(f,e.i("h<d>(1)").a(new A.fg()),d),d.i("h.E"))
f=A.D(d,A.k(d).c)
f.$flags=1
c=f
f=B.a.bk(B.I,0,new A.fh(),u.i)
e=u.d
d=A.j([],e)
for(b=b2.y,a=b.length,a0=u.N,a1=u.X,a2=0;a2<b.length;b.length===a||(0,A.v)(b),++a2){a3=b[a2]
d.push(A.G(["value",a3.h(0,"id"),"label",a3.h(0,c1)],a0,a1))}d=A.a1(b3,d,b3,b3,b9,c0,B.bi,b3,b3,b4,b3,b9,b3,t,b3)
b=i.length===1
a=b?c0:c3
a4=A.j([],u.x)
for(a5=i.length,a6=u.K,a2=0;a2<i.length;i.length===a5||(0,A.v)(i),++a2){a7=i[a2]
a8=B.a.I(b2.Q,new A.fi(a7)).h(0,c1)
a8=q.b(a8)?a8:A.i(A.f("schedule labels must be an object",b3))
a4.push(A.G(["value",a7.a,"label",a8],a0,a6))}i=A.a1(b3,a4,b3,b3,"schedule",a,B.bg,b3,b3,b8,b,c2,b3,j,b3)
b=A.j([],e)
for(a=J.O(A.aZ(r,b6));a.j();){a9=a.gk()
a4=(q.b(a9)?a9:A.i(A.f("variant must be an object",b3))).h(0,"id")
b.push(A.G(["value",a4,"label",a9.h(0,c1)],a0,a1))}b=A.a1(b3,b,b3,b3,"variant",c0,B.bv,b3,b3,b5,b3,b9,b3,s,b3)
a=A.a1(b3,B.b3,b3,b3,"max-mode",c3,B.bo,b3,b3,"maxMode",b3,c4,b3,"oneRepMax",b3)
a4=A.a1(b3,B.b2,b3,b3,"unit",c3,B.bu,b3,b3,"unit",b3,c4,b3,"kg",b3)
if(u.I.b(p.h(0,b7))){a5=A.H(p.h(0,b7),"example").h(0,"trainingMaxRatioBasisPoints")
if(a5==null)a5=9000}else a5=9000
a5=A.j([d,i,b,a,a4,A.a1(b3,b3,b3,b3,"training-max-ratio","percentage",B.be,1e4,1000,"globalTrainingMaxRatioBasisPoints",b3,c4,50,a5,b3)],e)
for(i=c.length,a2=0;a2<c.length;c.length===i||(0,A.v)(c),++a2){b0=c[a2]
d="maxInputs."+b0
b=b2.at.h(0,b0)
if(b==null)b=A.G(["en",b0,"fr",b0],a0,a0)
B.a.J(a5,A.j([A.a1(b3,b3,b3,b3,"max-load-"+b0,c4,b,b3,0,d+".weight",b3,c4,0.5,100,b3),A.a1(b3,b3,b3,b3,"max-repetitions-"+b0,"integer",B.bl,20,1,d+".repetitions",b3,c4,b3,5,B.b1)],e))}for(i=J.O(A.aZ(n,"parameters"));i.j();){a9=i.gk()
if(!J.N((q.b(a9)?a9:A.i(A.f("parameter must be an object",b3))).h(0,"presentationGroup"),"hidden"))a5.push(b2.bQ(a9))}a5.push(A.a1(b3,b3,b3,b3,"bar-weight",c4,B.bx,b3,0,"barWeight",b3,c5,0.5,20,b3))
for(a2=0;a2<7;++a2){q=A.A(B.I[a2])
a5.push(A.a1(b3,b3,b3,b3,"plate-"+q,"plate-counter",q+" kg",10,0,"plates."+q,b3,c5,b3,1,b3))}a5.push(A.a1(b3,b3,b3,b3,"maximum-plate-load",c4,B.bp,b3,b3,"maximumPlateLoad",!0,c5,b3,20+2*f,b3))
a5.push(A.a1(b3,b3,b3,b3,"start-date","date",B.br,b3,b3,"startDate",b3,c2,b3,"2026-01-05",b3))
q=u.s
i=A.j([],q)
for(f=g.d,e=f.length,a2=0;a2<f.length;f.length===e||(0,A.v)(f),++a2)i.push(f[a2])
e=A.j([],u.m)
for(d=f.length,a2=0;a2<f.length;f.length===d||(0,A.v)(f),++a2){b1=f[a2]
e.push(A.G(["value",b1,"label",A.l9(b1)],a0,a0))}a5.push(A.a1(b3,e,b3,b3,"session-order","token-order",B.bm,b3,b3,"sessionOrder",b3,c2,b3,i,b3))
a5.push(A.a1(b3,b3,b3,b3,"program-title","text",B.bf,b3,b3,"programTitle",b3,c6,b3,"5/3/1",b3))
a5.push(A.a1(b3,b3,b3,b3,"show-plating","boolean",B.bk,b3,b3,"showPlating",b3,c6,b3,!0,b3))
a5.push(A.a1(c7,b3,b3,b3,c7,"action",B.bj,b3,b3,c7,b3,c6,b3,!1,b3))
i=A.ax(b2.S(),a0,a1)
i.l(0,"id",t+"/"+s)
i.l(0,b4,t)
i.l(0,b5,s)
e=A.j([],q)
for(d=f.length,a2=0;a2<f.length;f.length===d||(0,A.v)(f),++a2)e.push(f[a2])
i.l(0,"movementIds",e)
q=A.j([],q)
for(e=f.length,a2=0;a2<f.length;f.length===e||(0,A.v)(f),++a2)q.push(f[a2])
i.l(0,"sessionIds",q)
i.l(0,"fields",a5)
return B.d.K(i,b3)},
aR(a){var t,s,r,q,p,o="warnings"
try{this.b1(a)
t=A.ax(this.S(),u.N,u.X)
J.c1(t,"valid",!0)
J.c1(t,"errors",B.j)
J.c1(t,o,B.j)
t=B.d.K(t,null)
return t}catch(q){s=A.hl(q)
t=u.N
p=u.X
r=A.ax(this.S(),t,p)
J.c1(r,"valid",!1)
J.c1(r,"errors",A.j([A.G(["code","INVALID_CYCLE_REQUEST","path","","messageKey","engine.invalidCycleRequest","details",A.G(["message",J.b1(A.hL(s))],t,t),"severity","error"],t,p)],u.d))
J.c1(r,o,B.j)
r=B.d.K(r,null)
return r}},
af(a){var t=this.b1(a).t(),s=A.hM(A.e7(t)),r=u.N,q=u.X,p=A.ax(this.S(),r,q)
p.l(0,"cycle",t)
p.l(0,"warnings",B.j)
q=A.ax(this.S(),r,q)
q.l(0,"kind","cycle")
q.l(0,"logicalHash",s)
q.l(0,"payload",t)
p.l(0,"snapshot",q)
return B.d.K(p,null)},
ah(b0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=null,a0="unit",a1="barProfile",a2="centiUnits",a3="initialTrainingMaxes",a4="slotRequests",a5="roundingIncrement",a6="macrocycle",a7="centiUnits must be an integer",a8="unit must be a string",a9=A.H(B.d.a1(b0,a),"forever request")
A.hQ(a9,B.cs)
A.h5(a9)
t=b.bK(B.a.I(b.as,new A.fj(a9)))
s=u.r
r=A.av(B.h,A.T(a9,a0),s)
q=A.H(a9.h(0,a1),a1)
p=A.h9(A.H(q.h(0,"weight"),"bar weight"))
o=A.j([],u.c)
for(n=J.O(A.aZ(q,"platesPerSide")),m=u.f;n.j();){l=n.gk()
k=m.b(l)?l:A.i(A.f("plate must be an object",a))
if(A.a2(k.h(0,a2))){j=k.h(0,a2)
j.toString
A.E(j)}else j=A.i(A.f(a7,a))
if(typeof k.h(0,a0)=="string"){k=k.h(0,a0)
k.toString
A.u(k)}else k=A.i(A.f(a8,a))
o.push(new A.x(j,A.av(B.h,k,s)))}n=A.T(a9,"macrocycleId")
k=A.i7(A.T(a9,"startDate"))
j=u.N
i=A.C(j,u.W)
for(h=A.H(a9.h(0,a3),a3).gB(),h=h.gn(h);h.j();){g=h.gk()
f=g.a
g=g.b
g=m.b(g)?g:A.i(A.f("training max must be an object",a))
if(A.a2(g.h(0,a2))){e=g.h(0,a2)
e.toString
A.E(e)}else e=A.i(A.f(a7,a))
if(typeof g.h(0,a0)=="string"){g=g.h(0,a0)
g.toString
A.u(g)}else g=A.i(A.f(a8,a))
i.l(0,f,new A.x(e,A.av(B.h,g,s)))}s=A.C(j,u.b2)
for(h=A.H(a9.h(0,a4),a4).gB(),h=h.gn(h);h.j();){g=h.gk()
e=g.a
g=g.b
s.l(0,e,b.bL(e,m.b(g)?g:A.i(A.f("slot request must be an object",a))))}d=A.l8(new A.eB(new A.dY(b.gbZ()),B.w).cc(t,new A.eD(n,t.a,t.b,k,i,s,r,A.h9(A.H(a9.h(0,a5),a5)),new A.d2(p,o))))
c=A.hM(A.e7(d))
s=u.X
o=A.ax(b.S(),j,s)
o.l(0,a6,d)
o.l(0,"warnings",B.j)
s=A.ax(b.S(),j,s)
s.l(0,"kind",a6)
s.l(0,"logicalHash",c)
s.l(0,"payload",d)
o.l(0,"snapshot",s)
return B.d.K(o,a)},
c_(a){return this.bY(a.a,a.b,B.r)},
bK(b8){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1="id",a2=null,a3="compatibilities",a4="repeatCount",a5="templateId",a6="variantId",a7="templateRevision",a8="variantRevision",a9="trainingMaxRule",b0="id must be a string",b1="cycle must be an object",b2="templateId must be a string",b3="variantId must be a string",b4="templateRevision must be an integer",b5="variantRevision must be an integer",b6="trainingMaxRule must be an object",b7=u.f
b7.a(b8)
A.aY(b8,B.cp)
t=A.T(b8,a1)
s=A.aX(b8,"revision")
r=A.h7(A.H(b8.h(0,a3),a3),"movements")
q=A.j([],u.dS)
for(p=J.O(A.aZ(b8,"phases")),o=u.d6,n=u.gL,m=u.dh,l=u.a;p.j();){k=p.gk()
j=b7.a(b7.b(k)?k:A.i(A.f("phase must be an object",a2)))
l.a(r)
A.aY(j,B.cG)
if(typeof j.h(0,a1)=="string"){i=j.h(0,a1)
i.toString
A.u(i)}else i=A.i(A.f(b0,a2))
if(typeof j.h(0,"role")=="string"){h=j.h(0,"role")
h.toString
A.u(h)}else h=A.i(A.f("role must be a string",a2))
h=A.av(B.bc,h,m)
if(A.a2(j.h(0,a4))){g=j.h(0,a4)
g.toString
A.E(g)}else g=A.i(A.f("repeatCount must be an integer",a2))
f=j.h(0,"cycle")
f=b7.a(b7.b(f)?f:A.i(A.f(b1,a2)))
A.aY(f,B.u)
if(typeof f.h(0,a5)=="string"){e=f.h(0,a5)
e.toString
A.u(e)}else A.i(A.f(b2,a2))
if(typeof f.h(0,a6)=="string"){e=f.h(0,a6)
e.toString
A.u(e)}else A.i(A.f(b3,a2))
if(A.a2(f.h(0,a7))){e=f.h(0,a7)
e.toString
A.E(e)}else A.i(A.f(b4,a2))
if(A.a2(f.h(0,a8))){f=f.h(0,a8)
f.toString
A.E(f)}else A.i(A.f(b5,a2))
f=j.h(0,"cycle")
f=b7.a(b7.b(f)?f:A.i(A.f(b1,a2)))
A.aY(f,B.u)
if(typeof f.h(0,a5)=="string"){e=f.h(0,a5)
e.toString
A.u(e)}else e=A.i(A.f(b2,a2))
if(typeof f.h(0,a6)=="string"){d=f.h(0,a6)
d.toString
A.u(d)}else d=A.i(A.f(b3,a2))
if(A.a2(f.h(0,a7))){c=f.h(0,a7)
c.toString
A.E(c)}else c=A.i(A.f(b4,a2))
if(A.a2(f.h(0,a8))){f=f.h(0,a8)
f.toString
A.E(f)}else f=A.i(A.f(b5,a2))
f=A.j([new A.aw(e,d,c,f)],n)
c=j.h(0,a9)
e=this.bA(b7.b(c)?c:A.i(A.f(b6,a2)),r)
d=j.h(0,a9)
d=J.N((b7.b(d)?d:A.i(A.f(b6,a2))).h(0,"type"),"testThenConfirm")
if(typeof j.h(0,a1)=="string"){j=j.h(0,a1)
j.toString
A.u(j)}else A.i(A.f(b0,a2))
q.push(new A.df(A.j([new A.cd(i,h,g,f,new A.eE(e,d))],o)))}b=A.H(b8.h(0,"labels"),"labels")
A.T(b,"en")
A.T(b,"fr")
A.h7(b8,"sourceRuleIds")
b7=A.j([],u.s)
for(p=q.length,a=0;a<q.length;q.length===p||(0,A.v)(q),++a)for(o=q[a].b,a0=0;a0<1;++a0)b7.push(o[a0].a)
return new A.fE(t,new A.de(s),q)},
bA(a,b){var t,s,r,q,p,o,n
u.f.a(a)
u.a.a(b)
t=A.T(a,"type")
if(t==="keep")return B.B
if(t==="testThenConfirm")return B.a2
if(t!=="add")throw A.a(A.f("UNKNOWN_CATALOG_TRAINING_MAX_RULE:"+t,null))
s=A.av(B.h,A.T(a,"unit"),u.r)
r=A.C(u.N,u.W)
for(q=b.length,p=0;p<b.length;b.length===q||(0,A.v)(b),++p){o=b[p]
n=this.ax.h(0,o)
r.l(0,o,new A.x(B.q.cH(A.hK(n==="horizontalPush"||n==="verticalPush"||o==="bench_press"||o==="overhead_press"?a.h(0,"upperBody"):a.h(0,"lowerBody"))*100),s))}return new A.bA(r,A.av(B.b_,A.T(a,"valueState"),u.d4))},
bF(a){u.f.a(a)
A.aY(a,B.u)
return new A.aw(A.T(a,"templateId"),A.T(a,"variantId"),A.aX(a,"templateRevision"),A.aX(a,"variantRevision"))},
bL(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f="percentageParameters",e="percentageParametersByMovement",d="trainingMaxRatioByMovementBasisPoints",c=u.f
c.a(b)
A.aY(b,B.cx)
if(A.T(b,"slotId")!==a)throw A.a(A.f("SLOT_ID_KEY_MISMATCH:"+a,null))
t=this.bF(A.H(b.h(0,"cycle"),"cycle"))
s=A.hO(b,"trainingDays")
r=A.j([],u.s)
for(q=A.h7(b,"sessionOrder"),p=q.length,o=0;o<q.length;q.length===p||(0,A.v)(q),++o)r.push(q[o])
q=A.h1(b.h(0,"enabled"))
p=u.N
n=u.A
m=A.C(p,n)
for(l=A.H(b.h(0,f),f).gB(),l=l.gn(l);l.j();){k=l.gk()
m.l(0,k.a,new A.W(A.E(k.b)))}l=A.C(p,u.l)
for(k=A.H(b.h(0,e),e).gB(),k=k.gn(k);k.j();){j=k.gk()
i=j.a
h=A.C(p,n)
j=j.b
j=(c.b(j)?j:A.i(A.f("movement parameters must be an object",null))).gB()
j=j.gn(j)
while(j.j()){g=j.gk()
h.l(0,g.a,new A.W(A.E(g.b)))}l.l(0,i,h)}c=A.aX(b,"globalTrainingMaxRatioBasisPoints")
n=A.C(p,n)
for(p=A.H(b.h(0,d),d).gB(),p=p.gn(p);p.j();){k=p.gk()
n.l(0,k.a,new A.W(A.E(k.b)))}return new A.dg(t,s,r,q,m,l,new A.W(c),n,A.h1(b.h(0,"includeDeload")))},
b1(c7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3=null,b4="unit",b5="barProfile",b6="weight",b7="platesPerSide",b8="centiUnits",b9="roundingIncrement",c0="maxInputs",c1="weightCentiUnits",c2="repetitions",c3="trainingDays",c4="centiUnits must be an integer",c5="unit must be a string",c6=A.H(B.d.a1(c7,b3),"cycle request")
A.hQ(c6,B.ck)
A.h5(c6)
t=A.T(c6,"templateId")
s=A.T(c6,"variantId")
r=A.h7(c6,"sessionOrder")
q=u.r
p=A.av(B.h,A.T(c6,b4),q)
o=this.ba(t,s,r,A.aW(c6.h(0,"scheduleId")))
n=this.av(t,s,r,o.a.a)
m=c6.h(0,"trainingMaxRatioByMovement")
if(m==null)m=c6.h(0,"trainingMaxRatioByMovementBasisPoints")
l=m==null?A.C(u.N,u.X):A.H(m,"map")
k=A.H(c6.h(0,b5),b5)
j=k.h(0,b6)==null?new A.x(A.aX(k,"barWeightCentiUnits"),p):A.h9(A.H(k.h(0,b6),"bar weight"))
m=u.c
if(k.h(0,b7)==null){m=A.j([],m)
for(i=A.hO(k,"platesPerSideCentiUnits"),h=i.length,g=0;g<i.length;i.length===h||(0,A.v)(i),++g)m.push(new A.x(i[g],p))
f=m}else{m=A.j([],m)
for(i=J.O(A.aZ(k,b7)),h=u.f;i.j();){e=i.gk()
d=h.b(e)?e:A.i(A.f("plate must be an object",b3))
if(A.a2(d.h(0,b8))){c=d.h(0,b8)
c.toString
A.E(c)}else c=A.i(A.f(c4,b3))
if(typeof d.h(0,b4)=="string"){d=d.h(0,b4)
d.toString
A.u(d)}else d=A.i(A.f(c5,b3))
m.push(new A.x(c,A.av(B.h,d,q)))}f=m}if(f.length===0)throw A.a(B.aK)
if(c6.h(0,b9)==null){m=A.y(f)
b=new A.x(new A.I(f,m.i("c(1)").a(new A.eY()),m.i("I<1,c>")).cC(0,new A.eZ())*2,p)}else b=A.h9(A.H(c6.h(0,b9),b9))
m=u.N
a=A.C(m,u.u)
for(i=A.H(c6.h(0,c0),c0).gB(),i=i.gn(i),h=u.f;i.j();){d=i.gk()
e=d.b
e=h.b(e)?e:A.i(A.f("max input must be an object",b3))
c=e.h(0,"type")
a0=A.aW(c==null?e.h(0,"kind"):c)
if(e.h(0,b6)==null){if(A.a2(e.h(0,c1))){c=e.h(0,c1)
c.toString
A.E(c)}else c=A.i(A.f("weightCentiUnits must be an integer",b3))
a1=new A.x(c,p)}else{c=e.h(0,b6)
c=h.b(c)?c:A.i(A.f("maximum weight must be an object",b3))
if(A.a2(c.h(0,b8))){a2=c.h(0,b8)
a2.toString
A.E(a2)}else a2=A.i(A.f(c4,b3))
if(typeof c.h(0,b4)=="string"){c=c.h(0,b4)
c.toString
A.u(c)}else c=A.i(A.f(c5,b3))
a1=new A.x(a2,A.av(B.h,c,q))}a3=d.a
A:{if("oneRepMax"===a0){d=new A.bM(a1)
break A}if("repMax"===a0){if(A.a2(e.h(0,c2))){d=e.h(0,c2)
d.toString
A.E(d)}else d=A.i(A.f("repetitions must be an integer",b3))
c=A.aW(e.h(0,"formula"))
d=new A.bQ(a1,d,c==null?"epley":c)
break A}if("directTrainingMax"===a0){d=new A.b5(a1)
break A}d=A.i(A.f("UNKNOWN_MAX_INPUT_KIND:"+A.A(a0),b3))}a.l(0,a3,d)}q=A.T(c6,"cycleId")
i=A.i7(A.T(c6,"startDate"))
d=c6.h(0,c3)==null?this.bG(o):A.hO(c6,c3)
c=A.j([],u.s)
for(a2=r.length,g=0;g<r.length;r.length===a2||(0,A.v)(r),++g)c.push(r[g])
a2=A.aX(c6,"globalTrainingMaxRatioBasisPoints")
a4=u.A
a5=A.C(m,a4)
for(a6=l.gB(),a6=a6.gn(a6);a6.j();){a7=a6.gk()
a5.l(0,a7.a,new A.W(A.E(a7.b)))}a6=A.C(m,a4)
a7=c6.h(0,"percentageParameters")
a7=(a7==null?A.C(m,u.X):A.H(a7,"map")).gB()
a7=a7.gn(a7)
while(a7.j()){a8=a7.gk()
a6.l(0,a8.a,new A.W(A.E(a8.b)))}a7=A.C(m,u.l)
a8=c6.h(0,"percentageParametersByMovement")
a8=(a8==null?A.C(m,u.X):A.H(a8,"map")).gB()
a8=a8.gn(a8)
a9=u.X
while(a8.j()){b0=a8.gk()
a3=b0.a
b1=A.C(m,a4)
b0=b0.b
if(b0==null)b0=A.C(m,a9)
else b0=h.b(b0)?b0:A.i(A.f("map must be an object",b3))
b0=b0.gB()
b0=b0.gn(b0)
while(b0.j()){b2=b0.gk()
b1.l(0,b2.a,new A.W(A.E(b2.b)))}a7.l(0,a3,b1)}m=A.iS(c6.h(0,"includeDeload"))
return B.w.bh(n,new A.db(q,i,d,c,a,new A.W(a2),a5,a6,a7,p,b,new A.d2(j,f),m!==!1))},
av(a,b,c,d){var t,s,r,q,p,o=this
u.a.a(c)
t=B.a.I(o.r,new A.f_(a))
s=B.a.I(t.c,new A.f0(b))
r=o.ba(a,b,c,d)
q=o.e
q.toString
p=o.w
return B.R.cE(B.Q.cG(q,o.x,r.a,p,"catalog.bundle.json:"+a+"/"+b,t,s))},
bY(a,b,c){return this.av(a,b,c,null)},
ba(a,b,c,d){var t,s,r,q,p,o
u.a.a(c)
t=B.a.I(B.a.I(this.r,new A.f3(a)).c,new A.f4(b))
s=this.w
r=A.y(s)
q=r.i("aa<1>")
s=A.D(new A.aa(s,r.i("o(1)").a(new A.f5(t)),q),q.i("h.E"))
s.$flags=1
p=s
s=A.y(p)
r=s.i("o(1)")
s=s.i("aa<1>")
q=u.G
o=A.i9(new A.aa(p,r.a(new A.f6(d,c)),s),q)
s=o==null?A.i9(new A.aa(p,r.a(new A.f7(d)),s),q):o
return s==null?B.a.gZ(p):s},
bG(a){var t,s,r,q,p=a.a.a
if(B.f.H(p,"two_day"))t=2
else t=B.f.H(p,"three_day")?3:a.b.length
s=J.ia(t,u.S)
for(r=0;r<t;r=q){q=r+1
s[r]=q}return s},
S(){var t=this.e
if(t==null||this.f==null)throw A.a(A.dP("ENGINE_NOT_INITIALIZED"))
return A.G(["apiVersion","v1","schemaVersion",1,"engineVersion","0.1.0","catalogVersion",t,"catalogHash",this.f],u.N,u.X)},
bQ(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d="id",c="presentationGroup"
u.f.a(a)
t=A.u(a.h(0,"type"))
A:{if("boolean"===t){s="boolean"
break A}if("integer"===t){s="integer"
break A}if("percentage"===t){s="percentage"
break A}if("choice"===t){s="choice"
break A}s="text"
break A}r=A.u(a.h(0,d))
q=A.A(a.h(0,d))
p=A.aW(a.h(0,c))
o=A.la(A.aW(a.h(0,c)))
n=a.h(0,"labelEn")
if(n==null)n=a.h(0,d)
m=a.h(0,"labelFr")
if(m==null)m=a.h(0,"labelEn")
if(m==null)m=a.h(0,d)
l=u.N
m=A.G(["en",n,"fr",m],l,u.X)
n=a.h(0,"default")
k=A.e6(a.h(0,"minimum"))
j=A.e6(a.h(0,"maximum"))
i=A.e6(a.h(0,"step"))
h=A.j([],u.c7)
g=u.gq.a(a.h(0,"allowedValues"))
g=J.O(g==null?B.j:g)
f=u.cp
while(g.j()){e=g.gk()
h.push(A.G(["value",e,"label",J.b1(e)],l,f))}return A.a1(null,h,p,o,r,s,m,j,k,"options."+q,null,"additional-options",i,n,null)},
$ikc:1}
A.fk.prototype={
$1(a){var t=A.H(a,"document")
A.aY(t,B.cA)
return A.H(t.h(0,"content"),"document content")},
$S:9}
A.fl.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"templates")},
$S:0}
A.fm.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"schedules")},
$S:0}
A.fn.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"components")},
$S:0}
A.fo.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"templates")},
$S:0}
A.fp.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"optionSchemas")},
$S:0}
A.fq.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"schedules")},
$S:0}
A.fr.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"foreverDefinitions")},
$S:0}
A.fs.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"movements")},
$S:0}
A.ft.prototype={
$1(a){return J.N(u.f.a(a).h(0,"kind"),"movements")},
$S:0}
A.f8.prototype={
$1(a){return J.N(u.f.a(a).h(0,"id"),this.a)},
$S:0}
A.f9.prototype={
$1(a){return A.H(a,"variant")},
$S:9}
A.fa.prototype={
$1(a){return J.N(u.f.a(a).h(0,"id"),this.a)},
$S:0}
A.fb.prototype={
$1(a){var t,s="revision"
u.f.a(a)
t=this.a
return J.N(a.h(0,"id"),t.h(0,"id"))&&J.N(a.h(0,s),t.h(0,s))},
$S:0}
A.fc.prototype={
$1(a){return u.R.a(a).a===this.a},
$S:6}
A.fd.prototype={
$1(a){return u.U.a(a).a===this.a},
$S:3}
A.fe.prototype={
$1(a){return u.h.a(a).a===this.a},
$S:4}
A.ff.prototype={
$1(a){return u.G.a(a).a.a===this.a},
$S:2}
A.fg.prototype={
$1(a){return u.Q.a(a).b},
$S:11}
A.fh.prototype={
$2(a,b){return A.hJ(a)+A.hJ(b)},
$S:45}
A.fi.prototype={
$1(a){return J.N(u.f.a(a).h(0,"id"),this.a.a)},
$S:0}
A.fj.prototype={
$1(a){var t
u.f.a(a)
t=this.a
return J.N(a.h(0,"id"),A.T(t,"definitionId"))&&J.N(a.h(0,"revision"),A.aX(t,"definitionRevision"))},
$S:0}
A.eY.prototype={
$1(a){return u.W.a(a).a},
$S:46}
A.eZ.prototype={
$2(a,b){A.E(a)
A.E(b)
return a<b?a:b},
$S:8}
A.f_.prototype={
$1(a){return u.R.a(a).a===this.a},
$S:6}
A.f0.prototype={
$1(a){return u.U.a(a).a===this.a},
$S:3}
A.f3.prototype={
$1(a){return u.R.a(a).a===this.a},
$S:6}
A.f4.prototype={
$1(a){return u.U.a(a).a===this.a},
$S:3}
A.f5.prototype={
$1(a){return B.a.N(this.a.c,new A.f2(u.G.a(a)))},
$S:2}
A.f2.prototype={
$1(a){var t
u.h.a(a)
t=this.a.a
return a.a===t.a&&a.b===t.b},
$S:4}
A.f6.prototype={
$1(a){var t=u.G.a(a).b,s=A.y(t),r=s.i("I<1,d>")
t=A.D(new A.I(t,s.i("d(1)").a(new A.f1()),r),r.i("q.E"))
t.$flags=1
if(this.a==null){s=this.b
t=s.length!==0&&A.ld(t,s)}else t=!1
return t},
$S:2}
A.f1.prototype={
$1(a){return u.Q.a(a).a},
$S:47}
A.f7.prototype={
$1(a){return u.G.a(a).a.a===this.a},
$S:2}
A.dY.prototype={$ika:1}
A.h8.prototype={
$1(a){return A.u(a)},
$S:5}
A.h4.prototype={
$1(a){return A.E(a)},
$S:48}
A.h6.prototype={
$1(a){return A.h1(a)},
$S:49}
A.h2.prototype={
$1(a){A.u(a)
return B.d.K(a,null)+":"+A.e7(this.a.h(0,a))},
$S:1}
A.dh.prototype={
aH(a){var t,s
A.u(a)
t=this.a
A.d3(a,"initialize")
s=t.a.aH(a)
A.d3(s,"initialize response")
t.b=!0
return s},
cn(){var t=this.a
if(!t.b)A.i(A.dP("ENGINE_NOT_INITIALIZED"))
t=A.ax(t.a.S(),u.N,u.X)
t.l(0,"capabilities",B.bb)
t=B.d.K(t,null)
A.d3(t,"engineInfo response")
return t},
aE(a){var t=this.a
return t.a7("catalogIndex",A.u(a),t.a.gaD())},
aG(a){var t=this.a
return t.a7("cycleEditorSchema",A.u(a),t.a.gaF())},
aR(a){var t=this.a
return t.a7("validateCycle",A.u(a),t.a.gaQ())},
af(a){var t=this.a
return t.a7("generateCycle",A.u(a),t.a.gae())},
ah(a){var t=this.a
return t.a7("generateMacrocycle",A.u(a),t.a.gag())}}
A.hi.prototype={
$0(){return this.a.a},
$S:51}
A.hj.prototype={
$0(){var t,s=this.a,r=v.G,q=A.cY(r.Object),p=A.cY(q.create.apply(q,[null]))
p.initialize=A.cZ(s.gcs())
p.engineInfo=A.iV(s.gcm())
p.catalogIndex=A.cZ(s.gaD())
p.cycleEditorSchema=A.cZ(s.gaF())
p.validateCycle=A.cZ(s.gaQ())
p.generateCycle=A.cZ(s.gae())
p.generateMacrocycle=A.cZ(s.gag())
q=A.cY(r.Object)
t=A.cY(q.create.apply(q,[null]))
t.get=A.iV(new A.hi(s))
r=A.cY(r.Object)
r.defineProperty.apply(r,[p,"_service",t])
return p},
$S:52};(function aliases(){var t=J.aL.prototype
t.bq=t.m})();(function installTearOffs(){var t=hunkHelpers._static_2,s=hunkHelpers._instance_1i,r=hunkHelpers._static_1,q=hunkHelpers._instance_1u,p=hunkHelpers._instance_0u
t(J,"kW","jQ",35)
s(J.l.prototype,"gcd","H",14)
r(A,"lo","kN",12)
q(A.d4.prototype,"gc6","c7",29)
r(A,"lr","e7",5)
var o
q(o=A.co.prototype,"gaD","aE",1)
q(o,"gaF","aG",1)
q(o,"gaQ","aR",1)
q(o,"gae","af",1)
q(o,"gag","ah",1)
q(o,"gbZ","c_",40)
q(o=A.dh.prototype,"gcs","aH",1)
p(o,"gcm","cn",50)
q(o,"gaD","aE",1)
q(o,"gaF","aG",1)
q(o,"gaQ","aR",1)
q(o,"gae","af",1)
q(o,"gag","ah",1)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.e,null)
r(A.e,[A.ht,J.dk,A.cA,J.b2,A.h,A.c5,A.F,A.fF,A.bg,A.cp,A.Z,A.cc,A.cb,A.a6,A.bK,A.c6,A.br,A.aQ,A.fI,A.fx,A.aK,A.K,A.eS,A.be,A.cn,A.cm,A.dp,A.fV,A.fO,A.fZ,A.aq,A.e2,A.fW,A.cR,A.e5,A.bs,A.z,A.cW,A.d7,A.d9,A.fS,A.h_,A.L,A.aD,A.e0,A.dD,A.cB,A.fP,A.ai,A.dj,A.R,A.cv,A.bS,A.dF,A.bO,A.ea,A.eg,A.am,A.b4,A.aJ,A.bD,A.fz,A.eA,A.fH,A.eX,A.dG,A.fA,A.da,A.x,A.W,A.bn,A.bk,A.aM,A.fG,A.bl,A.aN,A.aB,A.bm,A.dW,A.cy,A.d2,A.db,A.cf,A.bb,A.b9,A.ba,A.bc,A.eG,A.Q,A.bE,A.eB,A.e_,A.cP,A.de,A.aw,A.bU,A.eE,A.cd,A.df,A.fE,A.dg,A.eD,A.dT,A.ce,A.eJ,A.eb,A.aR,A.ay,A.az,A.aS,A.aH,A.d4,A.c4,A.co,A.dY,A.dh])
r(J.dk,[J.dm,J.ci,J.cj,J.bH,J.bI,J.bG,J.bd])
r(J.cj,[J.aL,J.l,A.bi,A.cs])
r(J.aL,[J.dE,J.bV,J.aF])
s(J.dl,A.cA)
s(J.eO,J.l)
r(J.bG,[J.ch,J.dn])
r(A.h,[A.aU,A.n,A.bh,A.aa,A.b6,A.cK,A.bW])
r(A.aU,[A.b3,A.cX])
s(A.cJ,A.b3)
s(A.cI,A.cX)
s(A.aC,A.cI)
r(A.F,[A.bJ,A.cC,A.dq,A.dV,A.dM,A.e1,A.ck,A.d0,A.at,A.cF,A.dU,A.bR,A.d8])
r(A.n,[A.q,A.ao,A.bf,A.a7])
s(A.ca,A.bh)
r(A.q,[A.I,A.aP,A.e4])
s(A.bX,A.bK)
s(A.cE,A.bX)
s(A.c7,A.cE)
s(A.t,A.c6)
r(A.aQ,[A.c8,A.cQ])
s(A.w,A.c8)
s(A.cw,A.cC)
r(A.aK,[A.d5,A.d6,A.dR,A.he,A.hg,A.fu,A.fN,A.ey,A.ez,A.fB,A.es,A.eu,A.ev,A.er,A.et,A.eL,A.eM,A.eF,A.eK,A.eN,A.eI,A.eC,A.ed,A.ee,A.ef,A.ec,A.en,A.ep,A.eo,A.eq,A.ej,A.ek,A.em,A.el,A.eh,A.ei,A.fk,A.fl,A.fm,A.fn,A.fo,A.fp,A.fq,A.fr,A.fs,A.ft,A.f8,A.f9,A.fa,A.fb,A.fc,A.fd,A.fe,A.ff,A.fg,A.fi,A.fj,A.eY,A.f_,A.f0,A.f3,A.f4,A.f5,A.f2,A.f6,A.f1,A.f7,A.h8,A.h4,A.h6,A.h2])
r(A.dR,[A.dQ,A.bC])
r(A.K,[A.aG,A.e3])
r(A.d6,[A.eP,A.hf,A.eT,A.fw,A.fT,A.fM,A.fC,A.fD,A.eH,A.fh,A.eZ])
r(A.cs,[A.dv,A.bL])
r(A.bL,[A.cL,A.cN])
s(A.cM,A.cL)
s(A.cq,A.cM)
s(A.cO,A.cN)
s(A.cr,A.cO)
r(A.cq,[A.dw,A.dx])
r(A.cr,[A.dy,A.dz,A.dA,A.dB,A.dC,A.ct,A.cu])
s(A.cS,A.e1)
s(A.ar,A.cQ)
s(A.ds,A.ck)
s(A.dr,A.d7)
r(A.d9,[A.eR,A.eQ,A.fK])
s(A.fR,A.fS)
r(A.d5,[A.ew,A.hi,A.hj])
r(A.at,[A.cx,A.di])
r(A.e0,[A.bq,A.aO,A.dO,A.cz,A.cg,A.a5,A.ah,A.an,A.du,A.bp])
r(A.bn,[A.bM,A.bQ,A.b5])
r(A.bk,[A.dd,A.dL,A.dS,A.d_])
r(A.aM,[A.bo,A.bN,A.c3,A.cD,A.bP])
r(A.bU,[A.cl,A.bA,A.bT])
t(A.cX,A.z)
t(A.cL,A.z)
t(A.cM,A.a6)
t(A.cN,A.z)
t(A.cO,A.a6)
t(A.bX,A.cW)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{c:"int",r:"double",ab:"num",d:"String",o:"bool",cv:"Null",p:"List",e:"Object",m:"Map",P:"JSObject"},mangledNames:{},types:["o(m<d,e?>)","d(d)","o(ay)","o(aS)","o(am)","d(e?)","o(aH)","~(e?,e?)","c(c,c)","m<d,e?>(e?)","am(e?)","p<d>(az)","@(@)","c(d?)","o(e?)","o(W)","o(bm)","o(c)","m<d,e>(x)","m<d,e>(bl)","m<d,e?>(bb)","m<d,e>(b9)","m<d,e>(ba)","R<d,m<d,e>>(d,x)","m<d,e>(bc)","o(aw)","o(aB)","o(x)","c(c,x)","aS(e?)","aR(e?)","ay(e?)","az(e?)","aH(e?)","c(x,x)","c(@,@)","b4(e?)","aN(e?)","0&()","@(@,d)","cy(aw)","c(c)","@(d)","~(@,@)","aJ(e?)","r(r,r)","c(x)","d(az)","c(e?)","o(o)","d()","c4()","P()","o(aN)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti")}
A.kC(v.typeUniverse,JSON.parse('{"dE":"aL","bV":"aL","aF":"aL","lR":"bi","dm":{"o":[],"B":[]},"ci":{"B":[]},"cj":{"P":[]},"aL":{"P":[]},"l":{"p":["1"],"n":["1"],"P":[],"h":["1"]},"dl":{"cA":[]},"eO":{"l":["1"],"p":["1"],"n":["1"],"P":[],"h":["1"]},"b2":{"M":["1"]},"bG":{"r":[],"ab":[],"a9":["ab"]},"ch":{"r":[],"c":[],"ab":[],"a9":["ab"],"B":[]},"dn":{"r":[],"ab":[],"a9":["ab"],"B":[]},"bd":{"d":[],"a9":["d"],"fy":[],"B":[]},"aU":{"h":["2"]},"c5":{"M":["2"]},"b3":{"aU":["1","2"],"h":["2"],"h.E":"2"},"cJ":{"b3":["1","2"],"aU":["1","2"],"n":["2"],"h":["2"],"h.E":"2"},"cI":{"z":["2"],"p":["2"],"aU":["1","2"],"n":["2"],"h":["2"]},"aC":{"cI":["1","2"],"z":["2"],"p":["2"],"aU":["1","2"],"n":["2"],"h":["2"],"z.E":"2","h.E":"2"},"bJ":{"F":[]},"n":{"h":["1"]},"q":{"n":["1"],"h":["1"]},"bg":{"M":["1"]},"bh":{"h":["2"],"h.E":"2"},"ca":{"bh":["1","2"],"n":["2"],"h":["2"],"h.E":"2"},"cp":{"M":["2"]},"I":{"q":["2"],"n":["2"],"h":["2"],"h.E":"2","q.E":"2"},"aa":{"h":["1"],"h.E":"1"},"Z":{"M":["1"]},"b6":{"h":["2"],"h.E":"2"},"cc":{"M":["2"]},"cb":{"M":["1"]},"aP":{"q":["1"],"n":["1"],"h":["1"],"h.E":"1","q.E":"1"},"c7":{"cE":["1","2"],"bX":["1","2"],"bK":["1","2"],"cW":["1","2"],"m":["1","2"]},"c6":{"m":["1","2"]},"t":{"c6":["1","2"],"m":["1","2"]},"cK":{"h":["1"],"h.E":"1"},"br":{"M":["1"]},"c8":{"aQ":["1"],"dN":["1"],"n":["1"],"h":["1"]},"w":{"c8":["1"],"aQ":["1"],"dN":["1"],"n":["1"],"h":["1"]},"cw":{"F":[]},"dq":{"F":[]},"dV":{"F":[]},"aK":{"b8":[]},"d5":{"b8":[]},"d6":{"b8":[]},"dR":{"b8":[]},"dQ":{"b8":[]},"bC":{"b8":[]},"dM":{"F":[]},"aG":{"K":["1","2"],"id":["1","2"],"m":["1","2"],"K.K":"1","K.V":"2"},"ao":{"n":["1"],"h":["1"],"h.E":"1"},"be":{"M":["1"]},"bf":{"n":["1"],"h":["1"],"h.E":"1"},"cn":{"M":["1"]},"a7":{"n":["R<1,2>"],"h":["R<1,2>"],"h.E":"R<1,2>"},"cm":{"M":["R<1,2>"]},"dp":{"k7":[],"fy":[]},"bi":{"P":[],"B":[]},"cs":{"P":[]},"dv":{"P":[],"B":[]},"bL":{"ae":["1"],"P":[]},"cq":{"z":["r"],"p":["r"],"ae":["r"],"n":["r"],"P":[],"h":["r"],"a6":["r"]},"cr":{"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"]},"dw":{"z":["r"],"p":["r"],"ae":["r"],"n":["r"],"P":[],"h":["r"],"a6":["r"],"B":[],"z.E":"r"},"dx":{"z":["r"],"p":["r"],"ae":["r"],"n":["r"],"P":[],"h":["r"],"a6":["r"],"B":[],"z.E":"r"},"dy":{"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"dz":{"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"dA":{"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"dB":{"hy":[],"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"dC":{"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"ct":{"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"cu":{"hz":[],"z":["c"],"p":["c"],"ae":["c"],"n":["c"],"P":[],"h":["c"],"a6":["c"],"B":[],"z.E":"c"},"e1":{"F":[]},"cS":{"F":[]},"cR":{"M":["1"]},"bW":{"h":["1"],"h.E":"1"},"ar":{"cQ":["1"],"aQ":["1"],"ig":["1"],"dN":["1"],"n":["1"],"h":["1"]},"bs":{"M":["1"]},"K":{"m":["1","2"]},"bK":{"m":["1","2"]},"cE":{"bX":["1","2"],"bK":["1","2"],"cW":["1","2"],"m":["1","2"]},"aQ":{"dN":["1"],"n":["1"],"h":["1"]},"cQ":{"aQ":["1"],"dN":["1"],"n":["1"],"h":["1"]},"e3":{"K":["d","@"],"m":["d","@"],"K.K":"d","K.V":"@"},"e4":{"q":["d"],"n":["d"],"h":["d"],"h.E":"d","q.E":"d"},"ck":{"F":[]},"ds":{"F":[]},"dr":{"d7":["e?","d"]},"hZ":{"a9":["hZ"]},"aD":{"a9":["aD"]},"r":{"ab":[],"a9":["ab"]},"c":{"ab":[],"a9":["ab"]},"p":{"n":["1"],"h":["1"]},"ab":{"a9":["ab"]},"d":{"a9":["d"],"fy":[]},"L":{"a9":["hZ"]},"e0":{"au":[]},"d0":{"F":[]},"cC":{"F":[]},"at":{"F":[]},"cx":{"F":[]},"di":{"F":[]},"cF":{"F":[]},"dU":{"F":[]},"bR":{"F":[]},"d8":{"F":[]},"dD":{"F":[]},"cB":{"F":[]},"dj":{"F":[]},"bS":{"k9":[]},"da":{"jF":[]},"bq":{"au":[]},"aO":{"au":[]},"bM":{"bn":[]},"bQ":{"bn":[]},"b5":{"bn":[]},"dd":{"bk":[]},"dL":{"bk":[]},"dS":{"bk":[]},"d_":{"bk":[]},"bo":{"aM":[]},"bN":{"aM":[]},"c3":{"aM":[]},"cD":{"aM":[]},"bP":{"aM":[]},"dO":{"au":[]},"cz":{"au":[]},"cg":{"au":[]},"a5":{"au":[]},"ah":{"au":[]},"an":{"au":[]},"bp":{"au":[]},"du":{"au":[]},"cl":{"bU":[]},"bA":{"bU":[]},"bT":{"bU":[]},"co":{"kc":[]},"dY":{"ka":[]},"jM":{"p":["c"],"n":["c"],"h":["c"]},"hz":{"p":["c"],"n":["c"],"h":["c"]},"ke":{"p":["c"],"n":["c"],"h":["c"]},"jK":{"p":["c"],"n":["c"],"h":["c"]},"hy":{"p":["c"],"n":["c"],"h":["c"]},"jL":{"p":["c"],"n":["c"],"h":["c"]},"kd":{"p":["c"],"n":["c"],"h":["c"]},"jI":{"p":["r"],"n":["r"],"h":["r"]},"jJ":{"p":["r"],"n":["r"],"h":["r"]}}'))
A.kB(v.typeUniverse,JSON.parse('{"cX":2,"bL":1,"d9":2}'))
var u=(function rtii(){var t=A.ak
return{n:t("aB"),dr:t("aJ"),gJ:t("b4"),e8:t("a9<@>"),h:t("am"),O:t("t<d,e>"),w:t("t<d,d>"),M:t("w<d>"),dy:t("aD"),Y:t("n<@>"),C:t("F"),aU:t("bD"),bV:t("aw"),ez:t("cd"),dh:t("an"),b2:t("dg"),Z:t("b8"),fK:t("b9"),aK:t("ce"),c2:t("ba"),gS:t("bb"),aC:t("bc"),hf:t("h<@>"),L:t("l<aB>"),k:t("l<bD>"),gL:t("l<aw>"),d6:t("l<cd>"),dS:t("l<df>"),fR:t("l<b9>"),gc:t("l<ce>"),d_:t("l<ba>"),cm:t("l<bb>"),gF:t("l<bc>"),x:t("l<m<d,e>>"),m:t("l<m<d,d>>"),c7:t("l<m<d,@>>"),d:t("l<m<d,e?>>"),eX:t("l<W>"),eG:t("l<bO>"),gt:t("l<dF>"),e3:t("l<bl>"),dP:t("l<bm>"),E:t("l<aR>"),_:t("l<ay>"),F:t("l<aH>"),s:t("l<d>"),gI:t("l<dW>"),c:t("l<x>"),a5:t("l<e_>"),bC:t("l<cP>"),b:t("l<@>"),t:t("l<c>"),T:t("ci"),o:t("P"),e:t("aF"),eA:t("ae<@>"),z:t("p<aB>"),ao:t("p<aJ>"),g1:t("p<am>"),dg:t("p<aR>"),D:t("p<ay>"),a:t("p<d>"),an:t("p<cP>"),j:t("p<@>"),J:t("p<e?>"),ct:t("R<d,m<d,e>>"),V:t("m<d,e>"),l:t("m<d,W>"),bv:t("m<d,bO>"),ck:t("m<d,d>"),p:t("m<d,x>"),I:t("m<@,@>"),f:t("m<d,e?>"),P:t("cv"),K:t("e"),A:t("W"),cH:t("bO"),q:t("aN"),gT:t("lS"),ft:t("aO"),bJ:t("aP<d>"),B:t("aP<c>"),cw:t("bl"),dm:t("bm"),cL:t("aR"),G:t("ay"),Q:t("az"),R:t("aH"),U:t("aS"),N:t("d"),dG:t("d(d)"),u:t("bn"),d4:t("bp"),ci:t("B"),ak:t("bV"),W:t("x"),r:t("bq"),v:t("L"),y:t("o"),i:t("r"),cp:t("@"),S:t("c"),eH:t("i8<cv>?"),bX:t("P?"),bM:t("p<@>?"),gq:t("p<e?>?"),X:t("e?"),dk:t("d?"),g:t("e5?"),fQ:t("o?"),cD:t("r?"),h6:t("c?"),cg:t("ab?"),H:t("ab"),cA:t("~(d,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.aV=J.dk.prototype
B.a=J.l.prototype
B.b=J.ch.prototype
B.q=J.bG.prototype
B.f=J.bd.prototype
B.aW=J.aF.prototype
B.aX=J.cj.prototype
B.bI=A.cu.prototype
B.K=J.dE.prototype
B.v=J.bV.prototype
B.P=new A.c3()
B.Q=new A.eb()
B.a_=new A.fz()
B.R=new A.eg()
B.m=new A.d4()
B.x=new A.eA()
B.a3=new A.fH()
B.n=new A.eX()
B.a0=new A.fA()
B.w=new A.da()
B.S=new A.cb(A.ak("cb<0&>"))
B.y=new A.dj()
B.z=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.T=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.Y=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.U=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.X=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.W=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.V=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.A=function(hooks) { return hooks; }

B.d=new A.dr()
B.B=new A.cl()
B.Z=new A.dD()
B.cZ=new A.fF()
B.d_=new A.dO(0,"straight")
B.a1=new A.fG()
B.a2=new A.bT()
B.a4=new A.cD()
B.a5=new A.fK()
B.i=new A.a5(4,"missingMaximum")
B.C=new A.a5(5,"invalidTrainingMaxRatio")
B.D=new A.a5(7,"unitMismatch")
B.p=new A.a5(8,"invalidRepMaxFormula")
B.ab=new A.a5(6,"invalidRoundingIncrement")
B.E=new A.Q(B.ab,"Rounding increment must be positive.")
B.ad=new A.Q(B.D,"Load and rounding increment units must match.")
B.ae=new A.Q(B.i,"A training max is required for a percentage load.")
B.a7=new A.a5(1,"invalidTrainingDays")
B.af=new A.Q(B.a7,"One weekday from 1 to 7 is required for every session.")
B.ag=new A.Q(B.i,"A maximum is required for a 1RM percentage load.")
B.ah=new A.Q(B.i,"A training max is required for a relative set load.")
B.o=new A.a5(10,"missingRelativeLoadTarget")
B.ai=new A.Q(B.o,"A relative load requires a main-work block in the same session.")
B.a6=new A.a5(0,"emptyCycleId")
B.aj=new A.Q(B.a6,"Cycle id cannot be empty.")
B.a9=new A.a5(2,"duplicateTrainingDays")
B.ak=new A.Q(B.a9,"Training weekdays must be unique.")
B.al=new A.Q(B.o,"Relative set loads require a TM-percentage main-work set.")
B.am=new A.Q(B.C,"Training-max ratios must be greater than 0% and at most 100%.")
B.aa=new A.a5(3,"unsupportedMovement")
B.an=new A.Q(B.aa,"Session order must contain every definition movement exactly once.")
B.ao=new A.Q(B.i,"A direct training max cannot resolve a 1RM percentage.")
B.ac=new A.a5(9,"invalidEquipment")
B.ap=new A.Q(B.ac,"Bar and plates must use the requested unit and positive plate weights.")
B.aq=new A.Q(B.p,"Epley repetitions must be positive.")
B.a8=new A.a5(11,"ambiguousRelativeLoadTarget")
B.ar=new A.Q(B.a8,"A relative load found multiple main-work blocks for its movement.")
B.as=new A.Q(B.o,"The referenced main-work set does not exist.")
B.F=new A.ah(1,"invalidDefinition")
B.au=new A.ah(2,"missingSlotRequest")
B.av=new A.ah(3,"unexpectedSlotRequest")
B.aw=new A.ah(4,"requiredSlotDisabled")
B.ax=new A.ah(5,"incompatibleCycle")
B.ay=new A.ah(6,"resolvedCycleMismatch")
B.G=new A.ah(7,"invalidTrainingMax")
B.az=new A.ah(8,"emptyGeneratedCycle")
B.at=new A.ah(0,"definitionMismatch")
B.aA=new A.bE(B.at,"The request does not target the resolved Forever definition.")
B.aB=new A.bE(B.F,"Unsupported Training Max rule.")
B.aC=new A.bE(B.G,"A Training Max increment uses a different unit.")
B.aJ=new A.ai("A plan requires at least one session.",null)
B.aK=new A.ai("PLATES_REQUIRED",null)
B.aL=new A.ai("CATALOG_RUNTIME_DOCUMENTS_REQUIRED",null)
B.aM=new A.ai("Schedule reference must resolve exactly once.",null)
B.aN=new A.ai("UNSUPPORTED_CONTRACT_VERSION",null)
B.aO=new A.ai("A plan requires exactly one of weekPlans or phases.",null)
B.aP=new A.ai("Variant requires exactly one of weekPlans or phases.",null)
B.aQ=new A.ai("Selected schedule is not allowed by variant.",null)
B.aR=new A.cg(0,"exactLoadUnavailable")
B.aS=new A.cf(B.aR,"The requested load cannot be plated exactly.")
B.H=new A.cg(1,"insufficientEquipment")
B.aT=new A.cf(B.H,"Available equipment cannot reach the requested load.")
B.aU=new A.cf(B.H,"The bar is heavier than the requested load.")
B.aY=new A.eQ(null)
B.aZ=new A.eR(null)
B.N=new A.bp(0,"projected")
B.O=new A.bp(1,"confirmed")
B.b_=t([B.N,B.O],A.ak("l<bp>"))
B.ce=new A.aO(0,"first")
B.cf=new A.aO(1,"second")
B.cg=new A.aO(2,"top")
B.b0=t([B.ce,B.cf,B.cg],A.ak("l<aO>"))
B.bW={path:0,operator:1,value:2}
B.bA=new A.t(B.bW,["maxMode","equals","repMax"],u.w)
B.b1=t([B.bA],u.m)
B.k={value:0,label:1}
B.bE=new A.t(B.k,["kg","kg"],u.w)
B.bF=new A.t(B.k,["lb","lb"],u.w)
B.b2=t([B.bE,B.bF],u.m)
B.I=t([25,20,15,10,5,2.5,1.25],A.ak("l<r>"))
B.c={en:0,fr:1}
B.bs=new A.t(B.c,["1 RM","1 RM"],u.w)
B.bB=new A.t(B.k,["oneRepMax",B.bs],u.O)
B.bh=new A.t(B.c,["Training Max","Training Max"],u.w)
B.bD=new A.t(B.k,["directTrainingMax",B.bh],u.O)
B.bz=new A.t(B.c,["Rep Max","Rep Max"],u.w)
B.bC=new A.t(B.k,["repMax",B.bz],u.O)
B.b3=t([B.bB,B.bD,B.bC],u.x)
B.cX=new A.bq(0,"kg")
B.cY=new A.bq(1,"lb")
B.h=t([B.cX,B.cY],A.ak("l<bq>"))
B.b8=t([],u.L)
B.ba=t([],A.ak("l<aJ>"))
B.b9=t([],A.ak("l<b4>"))
B.l=t([],u.d)
B.b7=t([],A.ak("l<lT>"))
B.b6=t([],u.E)
B.b5=t([],u._)
B.b4=t([],u.F)
B.r=t([],u.s)
B.J=t([],u.c)
B.j=t([],u.b)
B.bb=t(["catalogIndex","cycleEditorSchema","validateCycle","generateCycle","generateMacrocycle"],u.s)
B.aD=new A.an(0,"leader")
B.aE=new A.an(1,"anchor")
B.aF=new A.an(2,"transition")
B.aG=new A.an(3,"deload")
B.aH=new A.an(4,"test")
B.aI=new A.an(5,"custom")
B.bc=t([B.aD,B.aE,B.aF,B.aG,B.aH,B.aI],A.ak("l<an>"))
B.bd=new A.du(1,"scheduled")
B.be=new A.t(B.c,["Training Max ratio","Ratio Training Max"],u.w)
B.bf=new A.t(B.c,["Program title","Titre du programme"],u.w)
B.bg=new A.t(B.c,["Frequency","Fr\xe9quence"],u.w)
B.bi=new A.t(B.c,["Template","Mod\xe8le"],u.w)
B.bj=new A.t(B.c,["Generate","G\xe9n\xe9rer"],u.w)
B.bk=new A.t(B.c,["Show plating","Afficher les plaques"],u.w)
B.bl=new A.t(B.c,["Repetitions","R\xe9p\xe9titions"],u.w)
B.bm=new A.t(B.c,["Session order","Ordre des s\xe9ances"],u.w)
B.bn=new A.t(B.c,["Joker Sets","S\xe9ries Joker"],u.w)
B.bo=new A.t(B.c,["Maximum type","Type de maximum"],u.w)
B.bp=new A.t(B.c,["Maximum total","Total maximal"],u.w)
B.bq=new A.t(B.c,["Assistance","Assistance"],u.w)
B.br=new A.t(B.c,["Start date","Date de d\xe9part"],u.w)
B.bt=new A.t(B.c,["Conditioning","Conditionnement"],u.w)
B.bu=new A.t(B.c,["Unit","Unit\xe9"],u.w)
B.bv=new A.t(B.c,["Variant","Variante"],u.w)
B.bw=new A.t(B.c,["Warm-up","\xc9chauffement"],u.w)
B.bx=new A.t(B.c,["Bar weight","Poids de la barre"],u.w)
B.by=new A.t(B.c,["Deload","Deload"],u.w)
B.t={}
B.bG=new A.t(B.t,[],A.ak("t<d,m<d,d>>"))
B.bH=new A.t(B.t,[],u.w)
B.ch=new A.cz(0,"pending")
B.ci=new A.cz(1,"notRequired")
B.cb={id:0,revision:1,role:2,labels:3,sourceRuleIds:4,parameterSchemaIds:5,constraints:6,compatibilities:7,block:8}
B.cj=new A.w(B.cb,9,u.M)
B.c2={templateId:0,variantId:1,templateRevision:2,variantRevision:3}
B.u=new A.w(B.c2,4,u.M)
B.bT={apiVersion:0,schemaVersion:1,cycleId:2,templateId:3,variantId:4,scheduleId:5,startDate:6,trainingDays:7,sessionOrder:8,maxInputs:9,globalTrainingMaxRatioBasisPoints:10,trainingMaxRatioByMovement:11,trainingMaxRatioByMovementBasisPoints:12,percentageParameters:13,percentageParametersByMovement:14,options:15,unit:16,roundingIncrement:17,barProfile:18,includeDeload:19,programTitle:20,showPlating:21}
B.ck=new A.w(B.bT,22,u.M)
B.bY={id:0,revision:1}
B.cl=new A.w(B.bY,2,u.M)
B.c5={type:0}
B.L=new A.w(B.c5,1,u.M)
B.bP={apiVersion:0,schemaVersion:1,templateId:2,variantId:3,scheduleId:4}
B.cm=new A.w(B.bP,5,u.M)
B.c4={id:0,repeatCount:1,weekPlans:2}
B.cn=new A.w(B.c4,3,u.M)
B.c3={repetitions:0,load:1}
B.co=new A.w(B.c3,2,u.M)
B.bJ={id:0,revision:1,labels:2,sourceRuleIds:3,phases:4,compatibilities:5,editorSchema:6}
B.cp=new A.w(B.bJ,7,u.M)
B.bV={type:0,minimum:1,maximum:2}
B.cq=new A.w(B.bV,3,u.M)
B.bQ={id:0,role:1,sets:2,movementId:3}
B.cr=new A.w(B.bQ,4,u.M)
B.bR={apiVersion:0,schemaVersion:1,macrocycleId:2,definitionId:3,definitionRevision:4,startDate:5,initialTrainingMaxes:6,slotRequests:7,unit:8,roundingIncrement:9,barProfile:10}
B.cs=new A.w(B.bR,11,u.M)
B.bU={apiVersion:0,schemaVersion:1}
B.ct=new A.w(B.bU,2,u.M)
B.bS={id:0,role:1,movementIds:2}
B.cu=new A.w(B.bS,3,u.M)
B.bO={id:0,revision:1,labels:2,sourceRuleIds:3,type:4,sessions:5}
B.cv=new A.w(B.bO,6,u.M)
B.c_={movementId:0}
B.cw=new A.w(B.c_,1,u.M)
B.bL={slotId:0,cycle:1,trainingDays:2,sessionOrder:3,enabled:4,percentageParameters:5,percentageParametersByMovement:6,globalTrainingMaxRatioBasisPoints:7,trainingMaxRatioByMovementBasisPoints:8,includeDeload:9}
B.cx=new A.w(B.bL,10,u.M)
B.c8={type:0,minimum:1}
B.cy=new A.w(B.c8,2,u.M)
B.c9={type:0,total:1}
B.cz=new A.w(B.c9,2,u.M)
B.c1={path:0,content:1}
B.cA=new A.w(B.c1,2,u.M)
B.cc={weekNumber:0,componentIds:1}
B.cB=new A.w(B.cc,2,u.M)
B.e=new A.w(B.t,0,u.M)
B.bX={main_work:0,"main work":1}
B.cC=new A.w(B.bX,2,u.M)
B.c6={type:0,basisPoints:1}
B.M=new A.w(B.c6,2,u.M)
B.bZ={minimum:0}
B.cD=new A.w(B.bZ,1,u.M)
B.cd={type:0,position:1,multiplierBasisPoints:2}
B.cE=new A.w(B.cd,3,u.M)
B.c7={type:0,count:1}
B.cF=new A.w(B.c7,2,u.M)
B.bK={id:0,role:1,repeatCount:2,cycle:3,trainingMaxRule:4}
B.cG=new A.w(B.bK,5,u.M)
B.c0={id:0,revision:1,labels:2,sourceRuleIds:3,optionSchemaId:4,scheduleIds:5,compatibilities:6,validExample:7,weekPlans:8,phases:9,assistancePlanIds:10,conditioningDefinitionIds:11}
B.cH=new A.w(B.c0,12,u.M)
B.bN={schemaVersion:0,catalogVersion:1,status:2,coverage:3,documents:4,contentHash:5}
B.cI=new A.w(B.bN,6,u.M)
B.ca={weekPlans:0,phases:1,assistancePlanIds:2,conditioningDefinitionIds:3}
B.cJ=new A.w(B.ca,4,u.M)
B.bM={id:0,revision:1,labels:2,sourceRuleIds:3,variants:4}
B.cK=new A.w(B.bM,5,u.M)
B.cL=A.as("lM")
B.cM=A.as("lN")
B.cN=A.as("jI")
B.cO=A.as("jJ")
B.cP=A.as("jK")
B.cQ=A.as("jL")
B.cR=A.as("jM")
B.cS=A.as("e")
B.cT=A.as("hy")
B.cU=A.as("kd")
B.cV=A.as("ke")
B.cW=A.as("hz")})();(function staticFields(){$.fQ=null
$.ag=A.j([],A.ak("l<e>"))
$.ii=null
$.i1=null
$.i0=null
$.j3=null
$.j0=null
$.j6=null
$.hb=null
$.hh=null
$.hS=null
$.iy=null
$.iz=null
$.iA=null
$.iB=null
$.hA=A.dZ("_lastQuoRemDigits")
$.hB=A.dZ("_lastQuoRemUsed")
$.cH=A.dZ("_lastRemUsed")
$.hC=A.dZ("_lastRem_nsh")})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal,s=hunkHelpers.lazy
t($,"lP","j8",()=>A.j2("_$dart_dartClosure"))
t($,"lO","hm",()=>A.j2("_$dart_dartClosure_dartJSInterop"))
t($,"mb","jo",()=>A.j([new J.dl()],A.ak("l<cA>")))
t($,"lU","ja",()=>A.aI(A.fJ({
toString:function(){return"$receiver$"}})))
t($,"lV","jb",()=>A.aI(A.fJ({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"lW","jc",()=>A.aI(A.fJ(null)))
t($,"lX","jd",()=>A.aI(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
t($,"m_","jg",()=>A.aI(A.fJ(void 0)))
t($,"m0","jh",()=>A.aI(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
t($,"lZ","jf",()=>A.aI(A.iv(null)))
t($,"lY","je",()=>A.aI(function(){try{null.$method$}catch(r){return r.message}}()))
t($,"m2","jj",()=>A.aI(A.iv(void 0)))
t($,"m1","ji",()=>A.aI(function(){try{(void 0).$method$}catch(r){return r.message}}()))
t($,"m9","ac",()=>A.aT(0))
t($,"m7","aA",()=>A.aT(1))
t($,"m8","jm",()=>A.aT(2))
t($,"m5","hW",()=>$.aA().L(0))
t($,"m3","hV",()=>A.aT(1e4))
s($,"m6","jl",()=>A.iq("^\\s*([+-]?)((0x[a-f0-9]+)|(\\d+)|([a-z0-9]+))\\s*$",!1))
t($,"m4","jk",()=>A.k_(8))
t($,"lQ","j9",()=>A.iq("^([+-]?\\d{4,6})-?(\\d\\d)-?(\\d\\d)(?:[ T](\\d\\d)(?::?(\\d\\d)(?::?(\\d\\d)(?:[.,](\\d+))?)?)?( ?[zZ]| ?([-+])(\\d\\d)(?::?(\\d\\d))?)?)?$",!0))
t($,"ma","jn",()=>A.j4(B.cS))})();(function nativeSupport(){!function(){var t=function(a){var n={}
n[a]=1
return Object.keys(hunkHelpers.convertToFastObject(n))[0]}
v.getIsolateTag=function(a){return t("___dart_"+a+v.isolateTag)}
var s="___dart_isolate_tags_"
var r=Object[s]||(Object[s]=Object.create(null))
var q="_ZxYxX"
for(var p=0;;p++){var o=t(q+"_"+p+"_")
if(!(o in r)){r[o]=1
v.isolateTag=o
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.bi,SharedArrayBuffer:A.bi,ArrayBufferView:A.cs,DataView:A.dv,Float32Array:A.dw,Float64Array:A.dx,Int16Array:A.dy,Int32Array:A.dz,Int8Array:A.dA,Uint16Array:A.dB,Uint32Array:A.dC,Uint8ClampedArray:A.ct,CanvasPixelArray:A.ct,Uint8Array:A.cu})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.bL.$nativeSuperclassTag="ArrayBufferView"
A.cL.$nativeSuperclassTag="ArrayBufferView"
A.cM.$nativeSuperclassTag="ArrayBufferView"
A.cq.$nativeSuperclassTag="ArrayBufferView"
A.cN.$nativeSuperclassTag="ArrayBufferView"
A.cO.$nativeSuperclassTag="ArrayBufferView"
A.cr.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$1$0=function(){return this()}
Function.prototype.$1$1=function(a){return this(a)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.lG
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
//# sourceMappingURL=hybrid_training_engine.js.map
