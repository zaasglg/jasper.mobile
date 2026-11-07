import 'dart:convert';

/// Only finite geographic coordinates may enter the JavaScript map document.
List<(String, String, double, double)> validYandexTaskPoints(
  List<(String, String, double, double)> tasks,
) => tasks
    .where(
      (t) =>
          t.$1.isNotEmpty &&
          t.$3.isFinite &&
          t.$4.isFinite &&
          t.$3.abs() <= 90 &&
          t.$4.abs() <= 180,
    )
    .toList();

String buildYandexTaskMapHtml(
  String apiKey,
  List<(String, String, double, double)> tasks,
) {
  String js(dynamic value) => jsonEncode(value)
      .replaceAll('<', r'\u003c')
      .replaceAll('>', r'\u003e')
      .replaceAll('&', r'\u0026');
  final points = validYandexTaskPoints(
    tasks,
  ).map((t) => {'id': t.$1, 'title': t.$2, 'lat': t.$3, 'lng': t.$4}).toList();
  final url = Uri.https('api-maps.yandex.ru', '/2.1/', {
    'apikey': apiKey.trim(),
    'lang': 'ru_RU',
    'ns': 'josparYmaps',
  });
  return '''<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>html,body,#map{height:100%;width:100%;margin:0;padding:0;background:#f6f6f8;overflow:hidden}</style></head>
<body><div id="map"></div><script>
(function(){
'use strict';
const points = ${js(points)};
let map = null;
let failed = false;
function send(value) { if(window.JosparMap) window.JosparMap.postMessage(JSON.stringify(value)); }
function fail(){ if(!failed){failed=true;send({type:'error'});} }
function escapeText(value){return String(value).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
window.josparUpdateTasks = function(next){
  if(!map || !Array.isArray(next) || !next.length) return;
  map.geoObjects.removeAll();
  let south=90,west=180,north=-90,east=-180;
  next.forEach(function(point){
    const title=escapeText(point.title);
    const marker=new window.josparYmaps.Placemark([point.lat,point.lng],{hintContent:title,iconContent:title.length>36?title.slice(0,35)+'…':title},{preset:'islands#blueStretchyIcon'});
    marker.events.add('click',function(){send({type:'select',id:point.id});});
    map.geoObjects.add(marker);
    south=Math.min(south,point.lat);north=Math.max(north,point.lat);west=Math.min(west,point.lng);east=Math.max(east,point.lng);
  });
  if(next.length===1 || (south===north&&west===east)) map.setCenter([next[0].lat,next[0].lng],14);
  else Promise.resolve(map.setBounds([[south,west],[north,east]],{checkZoomRange:true,zoomMargin:35})).catch(function(){});
};
const script=document.createElement('script');
script.src=${js(url.toString())};script.async=true;script.onerror=fail;
script.onload=function(){
  if(!window.josparYmaps){fail();return;}
  try{window.josparYmaps.ready(function(){
    if(failed)return;
    try{
      map=new window.josparYmaps.Map('map',{center:points.length?[points[0].lat,points[0].lng]:[43.238949,76.889709],zoom:13,controls:['zoomControl']});
      window.josparUpdateTasks(points);
      new ResizeObserver(function(){map.container.fitToViewport();}).observe(document.getElementById('map'));
      send({type:'ready'});
    }catch(_){fail();}
  });}catch(_){fail();}
};
document.head.appendChild(script);
window.addEventListener('pagehide',function(){if(map){map.destroy();map=null;}});
})();
</script></body></html>''';
}
