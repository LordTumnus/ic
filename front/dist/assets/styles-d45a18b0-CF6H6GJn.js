import{o as e,t}from"./src-CXGiyJEg.js";import{B as n,Bt as r,E as i,It as a,Ot as o,c as s,j as c,m as l,st as u,v as d,w as f,x as p,z as m}from"./mermaid-7ea9cbd6-DV9bNuET.js";import{t as h}from"./channel-R3EyTFnj.js";import{t as g}from"./graphlib-Bf1QXnMJ.js";import{t as _}from"./index-5325376f-Bx6-1lXO.js";function v(e,t){return!!e.children(t).length}function y(e){return x(e.v)+`:`+x(e.w)+`:`+x(e.name)}var b=/:/g;function x(e){return e?String(e).replace(b,`\\:`):``}function S(e,t){t&&e.attr(`style`,t)}function C(e,t,n){t&&e.attr(`class`,t).attr(`class`,n+` `+e.attr(`class`))}function w(e,t){var n=t.graph();if(u(n)){var r=n.transition;if(o(r))return r(e)}return e}function T(e,t){var n=e.append(`foreignObject`).attr(`width`,`100000`),r=n.append(`xhtml:div`);r.attr(`xmlns`,`http://www.w3.org/1999/xhtml`);var i=t.label;switch(typeof i){case`function`:r.insert(i);break;case`object`:r.insert(function(){return i});break;default:r.html(i)}S(r,t.labelStyle),r.style(`display`,`inline-block`),r.style(`white-space`,`nowrap`);var a=r.node().getBoundingClientRect();return n.attr(`width`,a.width).attr(`height`,a.height),n}var E={},D=function(e){let t=Object.keys(e);for(let n of t)E[n]=e[n]},O=async function(e,t,n,r,a,o){let u=r.select(`[id="${n}"]`),f=Object.keys(e);for(let n of f){let r=e[n],f=`default`;r.classes.length>0&&(f=r.classes.join(` `)),f+=` flowchart-label`;let m=p(r.styles),h=r.text===void 0?r.id:r.text,g;if(i.info(`vertex`,r,r.labelType),r.labelType===`markdown`)i.info(`vertex`,r,r.labelType);else if(l(d().flowchart.htmlLabels))g=T(u,{label:h}).node(),g.parentNode.removeChild(g);else{let e=a.createElementNS(`http://www.w3.org/2000/svg`,`text`);e.setAttribute(`style`,m.labelStyle.replace(`color:`,`fill:`));let t=h.split(s.lineBreakRegex);for(let n of t){let t=a.createElementNS(`http://www.w3.org/2000/svg`,`tspan`);t.setAttributeNS(`http://www.w3.org/XML/1998/namespace`,`xml:space`,`preserve`),t.setAttribute(`dy`,`1em`),t.setAttribute(`x`,`1`),t.textContent=n,e.appendChild(t)}g=e}let _=0,v=``;switch(r.type){case`round`:_=5,v=`rect`;break;case`square`:v=`rect`;break;case`diamond`:v=`question`;break;case`hexagon`:v=`hexagon`;break;case`odd`:v=`rect_left_inv_arrow`;break;case`lean_right`:v=`lean_right`;break;case`lean_left`:v=`lean_left`;break;case`trapezoid`:v=`trapezoid`;break;case`inv_trapezoid`:v=`inv_trapezoid`;break;case`odd_right`:v=`rect_left_inv_arrow`;break;case`circle`:v=`circle`;break;case`ellipse`:v=`ellipse`;break;case`stadium`:v=`stadium`;break;case`subroutine`:v=`subroutine`;break;case`cylinder`:v=`cylinder`;break;case`group`:v=`rect`;break;case`doublecircle`:v=`doublecircle`;break;default:v=`rect`}let y=await c(h,d());t.setNode(r.id,{labelStyle:m.labelStyle,shape:v,labelText:y,labelType:r.labelType,rx:_,ry:_,class:f,style:m.style,id:r.id,link:r.link,linkTarget:r.linkTarget,tooltip:o.db.getTooltip(r.id)||``,domId:o.db.lookUpDomId(r.id),haveCallback:r.haveCallback,width:r.type===`group`?500:void 0,dir:r.dir,type:r.type,props:r.props,padding:d().flowchart.padding}),i.info(`setNode`,{labelStyle:m.labelStyle,labelType:r.labelType,shape:v,labelText:y,rx:_,ry:_,class:f,style:m.style,id:r.id,domId:o.db.lookUpDomId(r.id),width:r.type===`group`?500:void 0,type:r.type,dir:r.dir,props:r.props,padding:d().flowchart.padding})}},k=async function(e,t,n){i.info(`abc78 edges = `,e);let a=0,o={},l,u;if(e.defaultStyle!==void 0){let t=p(e.defaultStyle);l=t.style,u=t.labelStyle}for(let n of e){a++;let m=`L-`+n.start+`-`+n.end;o[m]===void 0?(o[m]=0,i.info(`abc78 new entry`,m,o[m])):(o[m]++,i.info(`abc78 new entry`,m,o[m]));let h=m+`-`+o[m];i.info(`abc78 new link id to be used is`,m,h,o[m]);let g=`LS-`+n.start,_=`LE-`+n.end,v={style:``,labelStyle:``};switch(v.minlen=n.length||1,n.type===`arrow_open`?v.arrowhead=`none`:v.arrowhead=`normal`,v.arrowTypeStart=`arrow_open`,v.arrowTypeEnd=`arrow_open`,n.type){case`double_arrow_cross`:v.arrowTypeStart=`arrow_cross`;case`arrow_cross`:v.arrowTypeEnd=`arrow_cross`;break;case`double_arrow_point`:v.arrowTypeStart=`arrow_point`;case`arrow_point`:v.arrowTypeEnd=`arrow_point`;break;case`double_arrow_circle`:v.arrowTypeStart=`arrow_circle`;case`arrow_circle`:v.arrowTypeEnd=`arrow_circle`;break}let y=``,b=``;switch(n.stroke){case`normal`:y=`fill:none;`,l!==void 0&&(y=l),u!==void 0&&(b=u),v.thickness=`normal`,v.pattern=`solid`;break;case`dotted`:v.thickness=`normal`,v.pattern=`dotted`,v.style=`fill:none;stroke-width:2px;stroke-dasharray:3;`;break;case`thick`:v.thickness=`thick`,v.pattern=`solid`,v.style=`stroke-width: 3.5px;fill:none;`;break;case`invisible`:v.thickness=`invisible`,v.pattern=`solid`,v.style=`stroke-width: 0;fill:none;`;break}if(n.style!==void 0){let e=p(n.style);y=e.style,b=e.labelStyle}v.style=v.style+=y,v.labelStyle=v.labelStyle+=b,n.interpolate===void 0?e.defaultInterpolate===void 0?v.curve=f(E.curve,r):v.curve=f(e.defaultInterpolate,r):v.curve=f(n.interpolate,r),n.text===void 0?n.style!==void 0&&(v.arrowheadStyle=`fill: #333`):(v.arrowheadStyle=`fill: #333`,v.labelpos=`c`),v.labelType=n.labelType,v.label=await c(n.text.replace(s.lineBreakRegex,`
`),d()),n.style===void 0&&(v.style=v.style||`stroke: #333; stroke-width: 1.5px;fill:none;`),v.labelStyle=v.labelStyle.replace(`color:`,`fill:`),v.id=h,v.classes=`flowchart-link `+g+` `+_,t.setEdge(n.start,n.end,v,a)}},A={setConf:D,addVertices:O,addEdges:k,getClasses:function(e,t){return t.db.getClasses()},draw:async function(r,a,o,s){i.info(`Drawing flowchart`);let c=s.db.getDirection();c===void 0&&(c=`TD`);let{securityLevel:l,flowchart:u}=d(),f=u.nodeSpacing||50,p=u.rankSpacing||50,h;l===`sandbox`&&(h=e(`#i`+a));let v=e(l===`sandbox`?h.nodes()[0].contentDocument.body:`body`),y=l===`sandbox`?h.nodes()[0].contentDocument:document,b=new g({multigraph:!0,compound:!0}).setGraph({rankdir:c,nodesep:f,ranksep:p,marginx:0,marginy:0}).setDefaultEdgeLabel(function(){return{}}),x,S=s.db.getSubGraphs();i.info(`Subgraphs - `,S);for(let e=S.length-1;e>=0;e--)x=S[e],i.info(`Subgraph - `,x),s.db.addVertex(x.id,{text:x.title,type:x.labelType},`group`,void 0,x.classes,x.dir);let C=s.db.getVertices(),w=s.db.getEdges();i.info(`Edges`,w);let T=0;for(T=S.length-1;T>=0;T--){x=S[T],t(`cluster`).append(`text`);for(let e=0;e<x.nodes.length;e++)i.info(`Setting up subgraphs`,x.nodes[e],x.id),b.setParent(x.nodes[e],x.id)}await O(C,b,a,v,y,s),await k(w,b);let E=v.select(`[id="${a}"]`);if(await _(v.select(`#`+a+` g`),b,[`point`,`circle`,`cross`],`flowchart`,a),n.insertTitle(E,`flowchartTitleText`,u.titleTopMargin,s.db.getDiagramTitle()),m(b,E,u.diagramPadding,u.useMaxWidth),s.db.indexNodes(`subGraph`+T),!u.htmlLabels){let e=y.querySelectorAll(`[id="`+a+`"] .edgeLabel .label`);for(let t of e){let e=t.getBBox(),n=y.createElementNS(`http://www.w3.org/2000/svg`,`rect`);n.setAttribute(`rx`,0),n.setAttribute(`ry`,0),n.setAttribute(`width`,e.width),n.setAttribute(`height`,e.height),t.insertBefore(n,t.firstChild)}}Object.keys(C).forEach(function(t){let n=C[t];if(n.link){let r=e(`#`+a+` [id="`+t+`"]`);if(r){let e=y.createElementNS(`http://www.w3.org/2000/svg`,`a`);e.setAttributeNS(`http://www.w3.org/2000/svg`,`class`,n.classes.join(` `)),e.setAttributeNS(`http://www.w3.org/2000/svg`,`href`,n.link),e.setAttributeNS(`http://www.w3.org/2000/svg`,`rel`,`noopener`),l===`sandbox`?e.setAttributeNS(`http://www.w3.org/2000/svg`,`target`,`_top`):n.linkTarget&&e.setAttributeNS(`http://www.w3.org/2000/svg`,`target`,n.linkTarget);let t=r.insert(function(){return e},`:first-child`),i=r.select(`.label-container`);i&&t.append(function(){return i.node()});let a=r.select(`.label`);a&&t.append(function(){return a.node()})}}})}},j=(e,t)=>{let n=h;return a(n(e,`r`),n(e,`g`),n(e,`b`),t)},M=e=>`.label {
    font-family: ${e.fontFamily};
    color: ${e.nodeTextColor||e.textColor};
  }
  .cluster-label text {
    fill: ${e.titleColor};
  }
  .cluster-label span,p {
    color: ${e.titleColor};
  }

  .label text,span,p {
    fill: ${e.nodeTextColor||e.textColor};
    color: ${e.nodeTextColor||e.textColor};
  }

  .node rect,
  .node circle,
  .node ellipse,
  .node polygon,
  .node path {
    fill: ${e.mainBkg};
    stroke: ${e.nodeBorder};
    stroke-width: 1px;
  }
  .flowchart-label text {
    text-anchor: middle;
  }
  // .flowchart-label .text-outer-tspan {
  //   text-anchor: middle;
  // }
  // .flowchart-label .text-inner-tspan {
  //   text-anchor: start;
  // }

  .node .katex path {
    fill: #000;
    stroke: #000;
    stroke-width: 1px;
  }

  .node .label {
    text-align: center;
  }
  .node.clickable {
    cursor: pointer;
  }

  .arrowheadPath {
    fill: ${e.arrowheadColor};
  }

  .edgePath .path {
    stroke: ${e.lineColor};
    stroke-width: 2.0px;
  }

  .flowchart-link {
    stroke: ${e.lineColor};
    fill: none;
  }

  .edgeLabel {
    background-color: ${e.edgeLabelBackground};
    rect {
      opacity: 0.5;
      background-color: ${e.edgeLabelBackground};
      fill: ${e.edgeLabelBackground};
    }
    text-align: center;
  }

  /* For html labels only */
  .labelBkg {
    background-color: ${j(e.edgeLabelBackground,.5)};
    // background-color: 
  }

  .cluster rect {
    fill: ${e.clusterBkg};
    stroke: ${e.clusterBorder};
    stroke-width: 1px;
  }

  .cluster text {
    fill: ${e.titleColor};
  }

  .cluster span,p {
    color: ${e.titleColor};
  }
  /* .cluster div {
    color: ${e.titleColor};
  } */

  div.mermaidTooltip {
    position: absolute;
    text-align: center;
    max-width: 200px;
    padding: 2px;
    font-family: ${e.fontFamily};
    font-size: 12px;
    background: ${e.tertiaryColor};
    border: 1px solid ${e.border2};
    border-radius: 2px;
    pointer-events: none;
    z-index: 100;
  }

  .flowchartTitleText {
    text-anchor: middle;
    font-size: 18px;
    fill: ${e.textColor};
  }
`;export{S as a,v as c,C as i,M as n,w as o,T as r,y as s,A as t};