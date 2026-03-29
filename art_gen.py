import requests, json, time
from PIL import Image
from rembg import remove, new_session
import io

with open('C:/Users/josef/.api_keys/keys.json') as f:
    keys = json.load(f)
API_KEY = keys['stability_ai']
OUT_TOWERS = 'c:/Users/josef/OneDrive/Dokumente/tower-defense-game/assets/textures/towers'
OUT_ENEMIES = 'c:/Users/josef/OneDrive/Dokumente/tower-defense-game/assets/textures/enemies'

session = new_session('isnet-general-use')

def generate_and_clean(prompt, out_path, aspect='1:1'):
    print(f'Generating: {out_path}...')
    r = requests.post(
        'https://api.stability.ai/v2beta/stable-image/generate/sd3',
        headers={'Authorization': f'Bearer {API_KEY}', 'Accept': 'image/*'},
        files={'none': ''},
        data={
            'prompt': prompt,
            'negative_prompt': 'blurry, ugly, realistic photo, text, watermark',
            'output_format': 'png',
            'model': 'sd3-turbo',
            'aspect_ratio': aspect,
        },
    )
    if r.status_code == 200:
        img = Image.open(io.BytesIO(r.content))
        output = remove(img, session=session)
        bbox = output.getbbox()
        if bbox:
            p = 3
            w, h = output.size
            bbox = (max(0,bbox[0]-p), max(0,bbox[1]-p), min(w,bbox[2]+p), min(h,bbox[3]+p))
            output = output.crop(bbox)
        output.save(out_path)
        print(f'  Saved and cleaned! {output.size}')
    else:
        print(f'  Error {r.status_code}: {r.text[:200]}')
    time.sleep(2)

# Cordula - pirate carnival character with hook arm
generate_and_clean(
    'Cartoon chibi game character, a fun carnival pirate girl with brown hair pulled back, wearing a colorful carnival costume with feathers, one arm is a pirate hook, holding a volleyball in the other hand, eyepatch, big smile, tower defense game sprite, clean outlines, white background',
    f'{OUT_TOWERS}/cordula.png'
)

# Cordula upgrade - Party Kanone version
generate_and_clean(
    'Cartoon chibi game character, epic carnival pirate queen with feathered hat, golden hook arm, surrounded by confetti and party cannons, glowing volleyball, tower defense game sprite upgraded powerful version, clean outlines, white background',
    f'{OUT_TOWERS}/cordula_upgrade.png'
)

# Now img2img the actual photos into characters
def img2img_character(photo_path, prompt, out_path, strength=0.7):
    print(f'img2img: {out_path}...')
    img = Image.open(photo_path).convert('RGB')
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img = img.resize((1024, 1024))
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)

    r = requests.post(
        'https://api.stability.ai/v2beta/stable-image/generate/sd3',
        headers={'Authorization': f'Bearer {API_KEY}', 'Accept': 'image/*'},
        files={'image': ('photo.png', buf, 'image/png')},
        data={
            'prompt': prompt,
            'negative_prompt': 'ugly, deformed, blurry, text',
            'output_format': 'png',
            'model': 'sd3-turbo',
            'strength': strength,
            'mode': 'image-to-image',
        },
    )
    if r.status_code == 200:
        img_out = Image.open(io.BytesIO(r.content))
        output = remove(img_out, session=session)
        bbox = output.getbbox()
        if bbox:
            p = 3
            w2, h2 = output.size
            bbox = (max(0,bbox[0]-p), max(0,bbox[1]-p), min(w2,bbox[2]+p), min(h2,bbox[3]+p))
            output = output.crop(bbox)
        output.save(out_path)
        print(f'  Saved! {output.size}')
    else:
        print(f'  Error {r.status_code}: {r.text[:200]}')
    time.sleep(2)

# img2img Kühne photo -> flower character
img2img_character(
    'C:/Users/josef/Downloads/Kuehne icon.jpg',
    'Adorable chibi cartoon flower girl, dark hair with sunflower petals crown, green leaf dress, shooting golden pollen sparkles, big cute eyes, full body game sprite, colorful clean outlines, tower defense character',
    f'{OUT_TOWERS}/kuhne_final.png',
    0.7
)

# img2img JoJo photo -> chemist character
img2img_character(
    'C:/Users/josef/Downloads/Josef icon.jpg',
    'Adorable chibi cartoon mad scientist, curly hair glasses mustache, white lab coat, holding bubbling green chemistry flask, colorful potions splashing, full body game sprite, clean outlines, tower defense character',
    f'{OUT_TOWERS}/jojo_final.png',
    0.7
)

# img2img Cordula photo -> pirate carnival character
img2img_character(
    'C:/Users/josef/Downloads/Cordula.jpg',
    'Adorable chibi cartoon pirate carnival girl, brown hair, wearing colorful feathered carnival costume, one arm is a golden pirate hook, holding a volleyball, fun and energetic, full body game sprite, clean outlines, tower defense character',
    f'{OUT_TOWERS}/cordula_final.png',
    0.7
)

# Now generate vegan enemy art
vegan_enemies = [
    ('Cartoon angry tofu sausage character with legs and angry face, vegan food monster, cute but menacing, game sprite, clean outlines, white background, tower defense enemy', f'{OUT_ENEMIES}/tofu_wurst.png'),
    ('Cartoon angry oat bar character running fast, healthy vegan snack bar with legs and angry eyes, speed lines, game sprite, clean outlines, white background', f'{OUT_ENEMIES}/hafer_riegel.png'),
    ('Cartoon giant soy steak character with armor plating, vegan protein monster, muscular and tough, game sprite, clean outlines, white background', f'{OUT_ENEMIES}/soja_steak.png'),
    ('Cartoon oat milk carton character wearing a doctor coat and stethoscope, friendly healer, vegan drink, game sprite, clean outlines, white background', f'{OUT_ENEMIES}/hafer_milch.png'),
    ('Cartoon flying avocado character with small wings, angry face, hovering with green glow, vegan food monster, game sprite, clean outlines, white background', f'{OUT_ENEMIES}/avocado.png'),
    ('Cartoon evil vegan devil boss character, big menacing figure made of vegetables, carrot horns, lettuce cape, glowing green eyes, orange M logo on chest, final boss, game sprite, clean outlines, white background', f'{OUT_ENEMIES}/vegan_teufel.png'),
]

for prompt, path in vegan_enemies:
    generate_and_clean(prompt, path)

print('All done!')
r = requests.get('https://api.stability.ai/v1/user/balance', headers={'Authorization': f'Bearer {API_KEY}'})
print(f'Credits remaining: {r.json()}')
