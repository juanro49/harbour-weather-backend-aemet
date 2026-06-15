import os
import xml.etree.ElementTree as ET
import json

def generate():
    data = {}
    translations_dir = 'translations'

    if not os.path.exists(translations_dir):
        print(f"Error: No se encuentra el directorio {translations_dir}")
        return

    for filename in os.listdir(translations_dir):
        if filename.endswith('.ts'):
            parts = filename.replace('.ts', '').split('-')
            # Extract language code from filename (e.g. harbour-weather-backend-aemet-es.ts -> es)
            lang = parts[-1].lower() if len(parts) > 1 else 'en'
            if lang == 'aemet': lang = 'en'

            tree = ET.parse(os.path.join(translations_dir, filename))
            root = tree.getroot()
            lang_data = {}

            for msg in root.findall('.//message'):
                msg_id = msg.get('id')
                if not msg_id: continue
                # Remove common prefix
                short_id = msg_id.replace('harbour-weather-aemet-', '')
                trans_node = msg.find('translation')
                text = trans_node.text if trans_node is not None else None
                if not text or trans_node.get('type') == 'unfinished':
                    source_node = msg.find('source')
                    text = source_node.text if source_node is not None else short_id
                lang_data[short_id] = text
            data[lang] = lang_data

    js_content = ".pragma library\n\n"
    js_content += "// Archivo generado automáticamente. No editar manualmente.\n"
    js_content += "var catalog = " + json.dumps(data, indent=4, ensure_ascii=False) + ";\n\n"
    js_content += "function translate(id, lang) {\n"
    js_content += "    var l = (lang || \"en\").toLowerCase().substring(0, 2);\n"
    js_content += "    if (!catalog[l]) l = \"en\";\n"
    js_content += "    var translation = catalog[l][id] || catalog[\"en\"][id] || id;\n"
    js_content += "    return translation;\n"
    js_content += "}\n"

    with open('backends/AEMETTranslations.js', 'w', encoding='utf-8') as f:
        f.write(js_content)
    print("AEMETTranslations.js (translate) generado con éxito.")

if __name__ == '__main__':
    generate()
