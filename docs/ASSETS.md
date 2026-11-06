# 素材记录

本版本主插画通过内置图片生成工具制作，透明背景，PNG 1536×1024。参考角色为用户明确要求的「线条小狗」白色小狗与小金毛。它是本次生成的非官方演绎素材，并非下载的官方素材包。

角色参考页面：https://www.marieclaire.com.tw/lifestyle/news/88371
参考图片：https://ian.marieclaire.com.tw/assets/mc/202509/68BBB6D550DDA1757132501.png?format=jpg&t=auto&w=1200%2C675

最终使用路径：`assets/illustrations/puppy_pair.png`。源图片原样内置；Flutter 显示时仅通过视口去除周围透明留白。桌面图标使用可编辑 SVG，导航小脸为 Flutter CustomPainter。

## 最终图片提示词

Create ONE transparent app illustration using EXACTLY the two established 线条小狗 cartoon characters in this reference image. This image is character/style reference, not a UI. Preserve their distinctive elongated, lumpy, simple silhouettes, tiny close-set black dot eyes, minimal w-shaped mouths and uneven thin black doodle outlines. White Maltese has tiny upright round ears and tall bean-like torso; tan golden retriever has floppy ears and thin coral red collar. They must look like the same characters as the LEFT pair in the reference, not generic kawaii puppies: no huge heads, no big eyes, no tongues, no realistic puppy anatomy. New pose: the two sit side by side with a SMALL open pale butter-yellow notebook across their laps, white dog holding a little pencil. One tiny pink heart above. Simple flat 2D solid white, sand beige, pale yellow, coral. No shadows, no glow, no shading, no texture. Single centered pair with full bodies and generous transparent outer margins, landscape 3:2 arrangement. No text or numbers, no extra dogs, no interface. Real alpha transparency.

## 0.1.2 新增图片

- puppy_peach.png：来源为用户上传“截屏2026-11-06 00.10.49.png”，保留粉色图中的前后贴贴姿势。
- puppy_sage.png：来源为用户上传“截屏2026-11-06 00.10.38.png”，保留草地图中左右并排依偎的姿势。

使用内置图片编辑工具，根据上传图片提取透明主体，移除背景和界面按钮；这是图像编辑输出，并非逐像素无损抠图。输出未再通过 Python 重绘。原始输出 PNG 已直接复制进资产目录。

编辑提示：保留参考图中两只小狗的姿势、表情、颜色与黑色线条，完整保留脚与尾巴，移除背景、地面阴影、爱心及界面按钮；输出透明背景，不新增物品、文字或其他角色。蜜桃粉保持金毛在后、白色小狗在前，草地绿保持白狗在左、金毛在右。

## 0.1.4 图标与历史开屏

- 桌面图标已改为用户本轮上传的「截屏2026-11-06 01.09.08.png」（双小狗在沙发上读书）。其字节原样保存在 assets/branding/launcher_original.png。tool/generate_icon.py 仅缩放/留边以生成 Android 多密度和自适应图标，不进行生成式重绘。
- assets/puppy_icon.svg 保留为旧图标和项目既有矢量风格来源，不再作为桌面图标生成输入。
- 0.1.4 曾使用 Flutter 路径自绘开屏角色。用户反馈外观不匹配，0.1.5 已移除此实现。
- 首页三套 PNG 没有修改。

## 0.1.5 开屏外观修正

直接使用 `assets/illustrations/puppy_sage.png` 原有双小狗依偎图。没有生成或编辑新的角色图片。只通过 Flutter 对完整图片轻微位移、旋转，配合问好气泡；不再声称单独挥爪。三张主题图片和桌面图标原图的 SHA-256 与 0.1.4 一致。

## 0.1.6 收支角色头像

PuppyAvatar 在 Flutter 中显示 puppy_sage.png 的局部圆形视口；白色小狗与小鸡毛分别选取原图的头部区域，仅等比缩放与裁切，无角色重绘、肢体变形或新图像生成。原 PNG 文件和开屏图片不变，头像不随主题替换；职责跟随账本分工设置。

## 0.1.7 分工头像

- `assets/avatars/golden_coin.jpg` 是用户上传的小鸡毛抱金币原图。SHA-256 `61c48acd88f76e1dbe562abd069520d29cb65cf49f525c80e4d41e509d9e1b50`。
- `assets/avatars/white_coin.jpg` 是用户上传的小白抱金币原图。SHA-256 `e8216b457b15dc0985e4d0b95ba22caf5083c7c76ecb1bb8d7b2e7e82616cbde`。
- 分工设置、首页收支卡片、记账表单及保存成功提示共用 `PuppyAvatar`。Flutter 在原有头像尺寸内等比缩放和圆形裁切，按角色选择图片。开屏、主题和装饰图标使用各自原有的素材。
