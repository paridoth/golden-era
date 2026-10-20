from pathlib import Path
import struct,zlib,collections,json,hashlib
root=Path(__file__).resolve().parents[3]
rows=[]
for p in sorted((root/'upstream/mineclonia/mods/ITEMS/mcl_core/schematics').glob('mcl_core_oak*.mts')):
 data=p.read_bytes(); version,sx,sy,sz=struct.unpack_from('>4H',data,4)
 assert data[:4]==b'MTSM' and version==4
 offset=12+sy; slices=list(data[12:offset]); names=[]
 names_count=struct.unpack_from('>H',data,offset)[0];offset+=2
 for _ in range(names_count):
  length=struct.unpack_from('>H',data,offset)[0];offset+=2
  names.append(data[offset:offset+length].decode());offset+=length
 bulk=zlib.decompress(data[offset:]);count=sx*sy*sz
 assert len(bulk)==count*4
 nodes=[]
 for i in range(count):
  name=names[struct.unpack_from('>H',bulk,2*i)[0]]
  if name=='air' or bulk[2*count+i]==0:continue
  nodes.append(dict(x=i%sx,y=(i//sx)%sy,z=i//(sx*sy),name=name,prob=bulk[2*count+i],param2=bulk[3*count+i]))
 logs=[n for n in nodes if n['name']=='mcl_trees:tree_oak']
 leaves=[n for n in nodes if n['name']=='mcl_trees:leaves_oak']
 cx,cz=sx//2,sz//2
 center=[n for n in logs if n['x']==cx and n['z']==cz]
 top=max(n['y'] for n in center)
 # Static envelope only: not execution of Elepower's neighbor exclusion or
 # Mineclonia's probabilistic schematic placement/leaf-decay callbacks.
 inside=lambda n:abs(n['x']-cx)<=2 and abs(n['z']-cz)<=2 and top<=n['y']<=top+4
 rows.append(dict(file=str(p.relative_to(root)),sha256=hashlib.sha256(data).hexdigest(),size=[sx,sy,sz],slices=slices,
  potential_logs=len(logs),potential_leaves=len(leaves),center_top=top,
  leaves_below_top=[n for n in leaves if n['y']<top],
  leaves_inside_nonv6_profile=sum(inside(n) for n in leaves),
  logs_outside_main_stem_and_nonv6_profile=[n for n in logs if n not in center and not inside(n)],
  leaves_by_y=dict(collections.Counter(n['y'] for n in leaves))))
out={'scope':'Read-only MTS v4 static parse; potential nodes before per-node/slice probabilities, schematic rotation and native callbacks. No engine run or machine simulation.',
 'format_source':'Luanti src/mapgen/mg_schematic.cpp:280-351 and src/mapnode.cpp:612-660',
 'oak_source':'Mineclonia mcl_core/nodes_trees.lua:7-18: classic weight 90%; large_1..4 weight 2.5% each.',
 'non_v6_profile':'Elepower treecutter.lua:1050-1058: range=2, range_up=4, range_down=0 relative to main-stem top.', 'rows':rows}
Path(__file__).with_name('schematic-summary.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps([{'file':Path(x['file']).name,'logs':x['potential_logs'],'leaves':x['potential_leaves'],'leaves_below_top':len(x['leaves_below_top']),'outlying_branch_logs':len(x['logs_outside_main_stem_and_nonv6_profile'])} for x in rows],indent=2))
