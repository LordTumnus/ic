/**
 * Built-in tile provider presets.
 * Maps provider name → URL template with {s}, {z}, {x}, {y} placeholders.
 */
export const tileProviders: Record<string, { url: string; attribution: string }> = {
  openstreetmap: {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap contributors',
  },
  'cartodb-light': {
    url: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
    attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
  },
  'cartodb-dark': {
    url: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
    attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
  },
  'opentopomap': {
    url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap contributors &copy; OpenTopoMap',
  },
  'osm-humanitarian': {
    url: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap contributors, Humanitarian OSM Team',
  },
  'esri-worldimagery': {
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '&copy; Esri',
  },
  'esri-worldtopomap': {
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    attribution: '&copy; Esri',
  },
};
