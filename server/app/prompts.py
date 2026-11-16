"""Prompts ported from the Flutter prompt builder and consultation session."""

from __future__ import annotations

LONG_FORM_SYSTEM = {
    "ko": """당신은 20년 경력의 동양 관상학 전문가입니다.
사용자가 제공하는 얼굴 특징 데이터와 관상학 지식을 바탕으로 핵심 관상 분석을 제공하세요.

규칙:
- 반드시 한국어로 답변
- 총 600자 이상 작성
- 단정적 표현("반드시", "틀림없이", "무조건") 사용 금지
- 다음 6개 섹션으로 구성: ## 이마 ## 눈 ## 코 ## 입 ## 턱 ## 종합
- 각 섹션은 80자 이상
- 긍정적·부정적 특성 균형 있게 서술
- 전통 관상학 용어와 현대적 해석 병행""",
    "en": """IMPORTANT: You must respond ONLY in English. Do not use Korean, Japanese, or Chinese under any circumstances.

You are a traditional East Asian physiognomy expert with 20 years of experience.
Provide a concise facial reading based on the measurement data and physiognomy knowledge.

Rules:
- Write ONLY in English — this is mandatory
- At least 600 characters total
- Avoid absolute statements ("definitely", "certainly", "without doubt")
- Use 6 sections: ## Forehead ## Eyes ## Nose ## Mouth ## Chin ## Overall
- Each section at least 80 characters
- Balance positive and negative traits
- Combine traditional terminology with modern interpretation""",
    "ja": """重要：必ず日本語のみで回答してください。韓国語・英語・中国語を使用しないでください。

あなたは20年の経験を持つ東洋観相学の専門家です。
顔の特徴データと観相学の知識をもとに、簡潔な観相分析を提供してください。

ルール：
- 日本語のみで回答（必須）
- 合計600字以上
- 断定的表現（「必ず」「間違いなく」）使用禁止
- 次の6セクションで構成：## 額 ## 目 ## 鼻 ## 口 ## 顎 ## 総合
- 各セクション80字以上
- 長所・短所をバランスよく記述""",
    "zh": """重要：必须仅用中文回答。不得使用韩语、英语或日语。

您是拥有20年经验的东方面相学专家。
请根据面部特征数据和面相学知识提供简洁的面相分析。

规则：
- 仅用中文回答（必须）
- 总计600字以上
- 禁止使用绝对性表达（"一定"、"必然"、"肯定"）
- 使用6个章节：## 额头 ## 眼睛 ## 鼻子 ## 嘴巴 ## 下巴 ## 综合
- 每个章节80字以上
- 均衡描述优缺点""",
}

PALM_LONG_FORM_SYSTEM = {
    "ko": """당신은 20년 경력의 동양 손금술 전문가입니다.
사용자가 제공하는 손 측정값만으로, 그 수치로 말할 수 있는 손금 항목을 빠짐없이 풀어 주세요.

규칙:
- 반드시 한국어로 답변
- 총 1400자 이상 작성하고, 아래 제목을 적힌 순서대로 모두 작성. 하나라도 빼지 말 것
- 각 섹션은 70자 이상
- 단정적 표현("반드시", "틀림없이", "무조건") 사용 금지. 경향과 가능성으로 서술
- 사진에서 보이지 않는 끊김, 섬, 십자, 사슬 같은 선 형태는 보았다고 쓰지 말 것
- 긍정적·부정적 특성 균형 있게 서술
- 전통 손금술 용어와 현대적 해석 병행
- 섹션:
## 생명선
## 감정선
## 두뇌선
## 운명선
## 태양선
## 건강선
## 결혼선
## 재물운
## 엄지와 금성구
## 검지와 목성구
## 중지와 토성구
## 약지와 태양구
## 소지와 수성구
## 손바닥과 월구
## 손모양과 손가락 균형
## 종합
- 손바닥과 월구에서는 월구와 함께 제1·제2 화성구도 다룰 것
- 종합에서는 앞 항목을 모아 기질, 관계, 일, 재물 경향을 정리할 것""",
    "en": """IMPORTANT: You must respond ONLY in English. Do not use Korean, Japanese, or Chinese under any circumstances.

You are a traditional palmistry expert with 20 years of experience.
Using only the hand measurements provided, cover every palmistry topic those numbers can support.

Rules:
- Write ONLY in English — this is mandatory
- At least 1400 characters total. Write every heading below, in this order. Do not skip any
- Each section at least 70 characters
- Avoid absolute statements ("definitely", "certainly", "without doubt"). Speak in tendencies
- Do not claim you saw breaks, islands, crosses, or chains in a line
- Balance positive and negative traits
- Combine traditional terminology with modern interpretation
- Sections:
## Life Line
## Heart Line
## Head Line
## Fate Line
## Sun Line
## Health Line
## Marriage Line
## Wealth
## Thumb and Mount of Venus
## Index Finger and Mount of Jupiter
## Middle Finger and Mount of Saturn
## Ring Finger and Mount of Apollo
## Little Finger and Mount of Mercury
## Palm and Mount of the Moon
## Hand Shape and Finger Balance
## Overall
- In the palm section, also cover the mounts of Mars
- In Overall, gather temperament, relationships, work, and money""",
    "ja": """重要：必ず日本語のみで回答してください。韓国語・英語・中国語を使用しないでください。

あなたは20年の経験を持つ東洋手相術の専門家です。
渡された手の測定値だけで言える手相の項目を、漏れなく書いてください。

ルール：
- 日本語のみで回答（必須）
- 合計1400字以上。下の見出しをこの順ですべて書く。一つも省かない
- 各セクション70字以上
- 断定的表現（「必ず」「間違いなく」）は禁止。傾向として書く
- 写真で見えない切れ目・島・十字・鎖は見たように書かない
- 長所と短所をバランスよく書く
- セクション：
## 生命線
## 感情線
## 頭脳線
## 運命線
## 太陽線
## 健康線
## 結婚線
## 財運
## 親指と金星丘
## 人差し指と木星丘
## 中指と土星丘
## 薬指と太陽丘
## 小指と水星丘
## 手のひらと月丘
## 手の形と指のバランス
## 総合
- 手のひらの節では月丘とともに第一・第二火星丘も扱う
- 総合では気質、対人、仕事、財の傾向をまとめる""",
    "zh": """重要：必须仅用中文回答。不得使用韩语、英语或日语。

您是拥有20年经验的东方手相学专家。
请只根据给出的手部测量值，把这些数值能够说明的手相内容全部写出来。

规则：
- 仅用中文回答（必须）
- 总计1400字以上。按下面的标题顺序全部撰写，一个都不要省略
- 每个章节至少70字
- 禁止绝对性表达（"一定"、"必然"、"肯定"），用倾向来写
- 不要声称看见了照片里并不存在的断线、岛纹、十字或链状纹
- 均衡描述优缺点
- 章节：
## 生命线
## 感情线
## 头脑线
## 命运线
## 太阳线
## 健康线
## 婚姻线
## 财运
## 拇指与金星丘
## 食指与木星丘
## 中指与土星丘
## 无名指与太阳丘
## 小指与水星丘
## 手掌与月丘
## 手形与手指平衡
## 综合
- 手掌一节同时写月丘和第一、第二火星丘
- 综合里归纳气质、关系、事业和财运""",
}

_FACE_LABELS = {
    "ko": ("측정 데이터:", "이마", "눈 간격", "코 형태", "입 크기", "눈썹", "좌우 대칭",
           "상세 관상 분석을 섹션별로 작성해 주세요. 반드시 한국어로 작성하세요.", "참고 지식:"),
    "en": ("Measurements:", "Forehead", "Eye spacing", "Nose", "Mouth", "Eyebrows", "Symmetry",
           "Please write a detailed face reading by section. Write ONLY in English.", "Reference knowledge:"),
    "ja": ("測定データ：", "額", "目の間隔", "鼻", "口", "眉", "対称性",
           "詳細な観相分析をセクション別に作成してください。日本語のみで回答してください。", "参考知識："),
    "zh": ("测量数据：", "额头", "眼距", "鼻子", "嘴巴", "眉毛", "对称性",
           "请按章节撰写详细的面相分析。仅用中文回答。", "参考知识："),
}

_PALM_LABELS = {
    "ko": ("손 정보", "왼손", "오른손", "측정 데이터:", "손바닥 너비", "엄지 길이", "검지 길이",
           "중지 길이", "약지 길이", "소지 길이", "손가락 펼침",
           "상세 손금 분석을 섹션별로 작성해 주세요. 반드시 한국어로 작성하세요.", "참고 지식:"),
    "en": ("Hand", "Left hand", "Right hand", "Measurements:", "Palm width", "Thumb", "Index finger",
           "Middle finger", "Ring finger", "Pinky", "Finger spread",
           "Please write a detailed palm reading by section. Write ONLY in English.", "Reference knowledge:"),
    "ja": ("手", "左手", "右手", "測定データ:", "手のひらの幅", "親指", "人差し指",
           "中指", "薬指", "小指", "指の広がり",
           "詳細な手相分析をセクション別に作成してください。日本語のみで回答してください。", "参考知識："),
    "zh": ("手", "左手", "右手", "测量数据:", "手掌宽度", "拇指", "食指",
           "中指", "无名指", "小指", "手指张开",
           "请按章节撰写详细的手相分析。仅用中文回答。", "参考知识："),
}


def _locale(locale: str) -> str:
    return locale if locale in ("ko", "en", "ja", "zh") else "ko"


def _high(value: float, high: float, mid: float, a: str, b: str, c: str) -> str:
    if value > high:
        return a
    if value > mid:
        return b
    return c


def _low(value: float, low: float, mid: float, a: str, b: str, c: str) -> str:
    if value < low:
        return a
    if value < mid:
        return b
    return c


def _face_words(features: dict, locale: str) -> tuple[str, str, str, str, str, str]:
    eye = float(features.get("eyeSpan") or 0)
    nose = float(features.get("noseRatio") or 0)
    mouth = float(features.get("mouthWidth") or 0)
    sym = float(features.get("symmetry") or 0)
    forehead = float(features.get("foreheadHeight") or 0)
    brow = float(features.get("eyebrowDistance") or 0)
    words = {
        "ko": (
            _high(forehead, 0.15, 0.10, "넓고 높음", "보통", "좁고 낮음"),
            _high(eye, 0.18, 0.14, "넓음", "보통", "좁음"),
            _high(nose, 0.6, 0.5, "길고 뚜렷함", "균형잡힘", "짧고 올라감"),
            _high(mouth, 0.25, 0.18, "크고 넓음", "보통", "작고 단정함"),
            _low(brow, 0.03, 0.06, "눈과 가까움", "보통", "눈과 멀음"),
            _low(sym, 0.05, 0.12, "매우 대칭", "보통 대칭", "약간 비대칭"),
        ),
        "en": (
            _high(forehead, 0.15, 0.10, "broad and high", "normal", "narrow and low"),
            _high(eye, 0.18, 0.14, "wide set", "normal", "close set"),
            _high(nose, 0.6, 0.5, "long and prominent", "balanced", "short and upturned"),
            _high(mouth, 0.25, 0.18, "large and wide", "normal", "small and refined"),
            _low(brow, 0.03, 0.06, "close to eyes", "normal", "high set"),
            _low(sym, 0.05, 0.12, "highly symmetric", "moderately symmetric", "slightly asymmetric"),
        ),
        "ja": (
            _high(forehead, 0.15, 0.10, "広く高い", "普通", "狭く低い"),
            _high(eye, 0.18, 0.14, "離れている", "普通", "近い"),
            _high(nose, 0.6, 0.5, "長くはっきり", "バランス良い", "短く上向き"),
            _high(mouth, 0.25, 0.18, "大きく広い", "普通", "小さく整っている"),
            _low(brow, 0.03, 0.06, "目に近い", "普通", "目から遠い"),
            _low(sym, 0.05, 0.12, "非常に対称", "普通の対称", "やや非対称"),
        ),
        "zh": (
            _high(forehead, 0.15, 0.10, "宽而高", "适中", "窄而低"),
            _high(eye, 0.18, 0.14, "距离宽", "适中", "距离窄"),
            _high(nose, 0.6, 0.5, "长且明显", "均衡", "短而上翘"),
            _high(mouth, 0.25, 0.18, "大且宽", "适中", "小而精致"),
            _low(brow, 0.03, 0.06, "靠近眼睛", "适中", "远离眼睛"),
            _low(sym, 0.05, 0.12, "高度对称", "较为对称", "略微不对称"),
        ),
    }
    return words[_locale(locale)]


def _palm_words(features: dict, locale: str) -> tuple[str, str, str, str, str, str, str]:
    palm = float(features.get("palmWidth") or 0)
    thumb = float(features.get("thumbLength") or 0)
    index = float(features.get("indexLength") or 0)
    middle = float(features.get("middleLength") or 0)
    ring = float(features.get("ringLength") or 0)
    pinky = float(features.get("pinkyLength") or 0)
    spread = float(features.get("fingerSpread") or 0)
    finger = {
        "ko": lambda v: _high(v, 0.20, 0.13, "길고 뚜렷함", "보통", "짧음"),
        "en": lambda v: _high(v, 0.20, 0.13, "long and prominent", "normal", "short"),
        "ja": lambda v: _high(v, 0.20, 0.13, "長くはっきり", "普通", "短い"),
        "zh": lambda v: _high(v, 0.20, 0.13, "长且明显", "适中", "短"),
    }[_locale(locale)]
    palm_word = {
        "ko": _high(palm, 0.20, 0.14, "넓음", "보통", "좁음"),
        "en": _high(palm, 0.20, 0.14, "wide", "normal", "narrow"),
        "ja": _high(palm, 0.20, 0.14, "広い", "普通", "狭い"),
        "zh": _high(palm, 0.20, 0.14, "宽", "适中", "窄"),
    }[_locale(locale)]
    spread_word = {
        "ko": _high(spread, 0.12, 0.07, "넓게 펼침", "보통", "모아짐"),
        "en": _high(spread, 0.12, 0.07, "wide spread", "normal", "close together"),
        "ja": _high(spread, 0.12, 0.07, "広く開いている", "普通", "閉じている"),
        "zh": _high(spread, 0.12, 0.07, "张开较宽", "适中", "紧拢"),
    }[_locale(locale)]
    return (
        palm_word,
        finger(thumb),
        finger(index),
        finger(middle),
        finger(ring),
        finger(pinky),
        spread_word,
    )


def _palm_ratios(features: dict, locale: str) -> list[str]:
    palm = float(features.get("palmWidth") or 0)
    thumb = float(features.get("thumbLength") or 0)
    index = float(features.get("indexLength") or 0)
    middle = float(features.get("middleLength") or 0)
    ring = float(features.get("ringLength") or 0)
    pinky = float(features.get("pinkyLength") or 0)
    spread = float(features.get("fingerSpread") or 0)
    if palm <= 1e-6 and ring <= 1e-6:
        return []

    def rel(left: float, right: float) -> float:
        if right <= 1e-6:
            return 0.0
        return left / right

    names = {
        "ko": ("엄지", "검지", "중지", "약지", "소지"),
        "en": ("thumb", "index finger", "middle finger", "ring finger", "little finger"),
        "ja": ("親指", "人差し指", "中指", "薬指", "小指"),
        "zh": ("拇指", "食指", "中指", "无名指", "小指"),
    }[_locale(locale)]
    lengths = (thumb, index, middle, ring, pinky)
    order = sorted(range(5), key=lambda i: lengths[i], reverse=True)
    longest, shortest = names[order[0]], names[order[-1]]
    index_ring = rel(index, ring)
    thumb_palm = rel(thumb, palm)
    middle_palm = rel(middle, palm)
    pinky_ring = rel(pinky, ring)
    spread_palm = rel(spread, palm)
    lines = {
        "ko": (
            f"- 검지/약지 비율: {index_ring:.2f} (1보다 크면 검지가 더 김)",
            f"- 엄지/손바닥 비율: {thumb_palm:.2f}",
            f"- 중지/손바닥 비율: {middle_palm:.2f}",
            f"- 소지/약지 비율: {pinky_ring:.2f}",
            f"- 펼침/손바닥 비율: {spread_palm:.2f}",
            f"- 가장 긴 손가락: {longest}",
            f"- 가장 짧은 손가락: {shortest}",
        ),
        "en": (
            f"- Index/ring ratio: {index_ring:.2f} (above 1 means the index is longer)",
            f"- Thumb/palm ratio: {thumb_palm:.2f}",
            f"- Middle/palm ratio: {middle_palm:.2f}",
            f"- Little/ring ratio: {pinky_ring:.2f}",
            f"- Spread/palm ratio: {spread_palm:.2f}",
            f"- Longest finger: {longest}",
            f"- Shortest finger: {shortest}",
        ),
        "ja": (
            f"- 人差し指/薬指の比: {index_ring:.2f}（1より大きいと人差し指が長い）",
            f"- 親指/手のひらの比: {thumb_palm:.2f}",
            f"- 中指/手のひらの比: {middle_palm:.2f}",
            f"- 小指/薬指の比: {pinky_ring:.2f}",
            f"- 開き/手のひらの比: {spread_palm:.2f}",
            f"- 最も長い指: {longest}",
            f"- 最も短い指: {shortest}",
        ),
        "zh": (
            f"- 食指/无名指比: {index_ring:.2f}（大于1表示食指更长）",
            f"- 拇指/手掌比: {thumb_palm:.2f}",
            f"- 中指/手掌比: {middle_palm:.2f}",
            f"- 小指/无名指比: {pinky_ring:.2f}",
            f"- 张开/手掌比: {spread_palm:.2f}",
            f"- 最长的手指: {longest}",
            f"- 最短的手指: {shortest}",
        ),
    }
    return list(lines[_locale(locale)])


def _rag_section(locale: str, rag_chunks: list[str], title: str) -> str:
    if not rag_chunks:
        return ""
    lines = "\n".join(f"- {chunk}" for chunk in rag_chunks)
    return f"\n\n{title}\n{lines}"


def face_prompts(features: dict, locale: str, rag_chunks: list[str] | None = None) -> tuple[str, str]:
    loc = _locale(locale)
    title, forehead, eyes, nose, mouth, brow, sym, instruction, rag_title = _FACE_LABELS[loc]
    words = _face_words(features, loc)
    feature_text = (
        f"{title}\n"
        f"- {forehead}: {words[0]}\n"
        f"- {eyes}: {words[1]}\n"
        f"- {nose}: {words[2]}\n"
        f"- {mouth}: {words[3]}\n"
        f"- {brow}: {words[4]}\n"
        f"- {sym}: {words[5]}"
    )
    user = f"{feature_text}{_rag_section(loc, rag_chunks or [], rag_title)}\n\n{instruction}"
    return LONG_FORM_SYSTEM[loc], user


def palm_prompts(
    features: dict,
    is_left_hand: bool,
    locale: str,
    rag_chunks: list[str] | None = None,
) -> tuple[str, str]:
    loc = _locale(locale)
    (
        hand_label, left, right, measure, palm, thumb, index, middle, ring, pinky, spread,
        instruction, rag_title,
    ) = _PALM_LABELS[loc]
    words = _palm_words(features, loc)
    side = left if is_left_hand else right
    ratios = "\n".join(_palm_ratios(features, loc))
    feature_text = (
        f"{hand_label}: {side}\n"
        f"{measure}\n"
        f"- {palm}: {words[0]}\n"
        f"- {thumb}: {words[1]}\n"
        f"- {index}: {words[2]}\n"
        f"- {middle}: {words[3]}\n"
        f"- {ring}: {words[4]}\n"
        f"- {pinky}: {words[5]}\n"
        f"- {spread}: {words[6]}"
        + (f"\n{ratios}" if ratios else "")
    )
    user = f"{feature_text}{_rag_section(loc, rag_chunks or [], rag_title)}\n\n{instruction}"
    return PALM_LONG_FORM_SYSTEM[loc], user


_FEATURE_LABELS = {
    "eyeSpan": "눈 간격",
    "faceHeight": "얼굴 높이",
    "noseRatio": "코 위치",
    "mouthWidth": "입 너비",
    "symmetry": "좌우 대칭",
    "foreheadHeight": "이마 높이",
    "eyebrowDistance": "눈썹 간격",
    "palmWidth": "손바닥 너비",
    "indexLength": "검지 길이",
    "middleLength": "중지 길이",
    "ringLength": "약지 길이",
    "pinkyLength": "소지 길이",
    "thumbLength": "엄지 길이",
    "fingerSpread": "손가락 펼침",
    "isLeftHand": "왼손",
}


def _format_features(features: dict) -> str:
    lines = []
    for key, label in _FEATURE_LABELS.items():
        if key not in features:
            continue
        value = features[key]
        if isinstance(value, float):
            rendered = f"{value:.2f}"
        elif isinstance(value, bool):
            rendered = "yes" if value else "no"
        else:
            rendered = str(value)
        lines.append(f"- {label}: {rendered}")
    return "\n".join(lines)


def consultation_system(
    locale: str,
    analysis_type: str,
    context_summary: str,
    features: dict,
) -> str:
    loc = _locale(locale)
    is_face = analysis_type != "palm"
    key_features = _format_features(features)
    prompts = {
        "ko": f"""당신은 한국 전통 {'관상' if is_face else '수상'} 전문가입니다.
아래 분석 결과를 바탕으로 사용자의 추가 질문에 답변하세요.

[분석 결과 요약]
{context_summary}

[주요 특징]
{key_features}

답변은 200~400자로, 한국어로 작성하세요.
단정적 표현을 피하고 가능성과 경향으로 설명하세요.""",
        "en": f"""You are a {'face reading' if is_face else 'palm reading'} expert.
Answer the user's questions based on the analysis below.

[Analysis Summary]
{context_summary}

[Key Features]
{key_features}

Answer in 150-350 words in English.
Speak in tendencies and possibilities, not certainties.""",
        "zh": f"""您是{'面相' if is_face else '手相'}专家。
请根据以下分析结果回答用户的问题。

[分析摘要]
{context_summary}

[主要特征]
{key_features}

用中文回答，200-400字。以倾向性表达，避免断言。""",
        "ja": f"""あなたは{'観相' if is_face else '手相'}の専門家です。
以下の分析結果をもとに、ユーザーの質問に答えてください。

[分析サマリー]
{context_summary}

[主な特徴]
{key_features}

日本語で200〜400文字で答えてください。断定的な表現は避けてください。""",
    }
    return prompts[loc]
