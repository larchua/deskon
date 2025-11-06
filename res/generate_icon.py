#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成DeskON新logo的.ico图标文件
基于Flutter中buildDeskONLogo的设计
"""

from PIL import Image, ImageDraw
import os

def generate_deskon_logo(size):
    """生成DeskON logo图像"""
    # 创建透明背景
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 计算比例
    border_radius = int(size * 0.18)
    center_x, center_y = size // 2, size // 2
    
    # 绘制渐变背景（从蓝色到深蓝色）
    # 由于PIL不支持渐变，我们使用深蓝色作为背景
    bg_color = (37, 99, 235)  # #2563EB (深蓝色)
    
    # 绘制圆角矩形背景
    draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)],
        radius=border_radius,
        fill=bg_color
    )
    
    # 绘制外部装饰圆环（仅在较大尺寸时显示）
    if size > 30:
        ring_size = int(size * 0.75)
        ring_x = (size - ring_size) // 2
        ring_y = (size - ring_size) // 2
        ring_width = max(int(size * 0.04), 1)
        
        draw.ellipse(
            [(ring_x, ring_y), (ring_x + ring_size, ring_y + ring_size)],
            outline=(255, 255, 255, 64),  # 白色，25%透明度
            width=ring_width
        )
    
    # 绘制中心圆点
    dot_size = int(size * 0.32)
    dot_x = center_x - dot_size // 2
    dot_y = center_y - dot_size // 2
    
    draw.ellipse(
        [(dot_x, dot_y), (dot_x + dot_size, dot_y + dot_size)],
        fill=(255, 255, 255, 255)  # 白色
    )
    
    # 绘制"D"字母设计 - 左侧竖线
    if size > 20:
        line_width = max(int(size * 0.08), 2)
        line_x = center_x - int(size * 0.15)
        line_top = center_y - int(size * 0.25)
        line_bottom = center_y + int(size * 0.25)
        
        draw.rectangle(
            [(line_x, line_top), (line_x + line_width, line_bottom)],
            fill=(59, 130, 246, 255)  # #3B82F6 (蓝色)
        )
        
        # 绘制"D"字母的弧形部分
        arc_size = int(size * 0.4)
        arc_x = line_x - arc_size // 2
        arc_y = center_y - arc_size // 2
        
        # 绘制弧形（使用椭圆的一部分）
        bbox = [(arc_x, arc_y), (arc_x + arc_size, arc_y + arc_size)]
        draw.arc(bbox, start=90, end=270, fill=(59, 130, 246, 255), width=line_width)
        
        # 连接弧形和竖线
        draw.rectangle(
            [(line_x, line_top), (line_x + line_width, line_top + line_width)],
            fill=(59, 130, 246, 255)
        )
        draw.rectangle(
            [(line_x, line_bottom - line_width), (line_x + line_width, line_bottom)],
            fill=(59, 130, 246, 255)
        )
    
    return img

def generate_ico_file(output_path, sizes=[16, 32, 48, 64, 128, 256]):
    """生成包含多个尺寸的.ico文件"""
    images = []
    for size in sizes:
        img = generate_deskon_logo(size)
        images.append(img)
    
    # 保存为ICO文件（PIL的ICO格式支持多尺寸）
    # 使用第一个图像作为基础，并传递所有尺寸
    try:
        images[0].save(
            output_path,
            format='ICO',
            sizes=[(img.width, img.height) for img in images]
        )
        print(f"Generated {output_path} with sizes: {sizes}")
    except Exception as e:
        print(f"Warning when saving with sizes: {e}")
        # 如果失败，尝试只保存第一个尺寸
        images[0].save(output_path, format='ICO')
        print(f"Generated {output_path} with single size: {sizes[0]}")

if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 生成主图标（ICO格式）
    icon_path = os.path.join(script_dir, 'icon.ico')
    generate_ico_file(icon_path)
    
    # 生成主图标（PNG格式，用于Flutter assets）
    icon_png_path = os.path.join(script_dir, 'icon.png')
    icon_png = generate_deskon_logo(512)  # 生成512x512的PNG
    icon_png.save(icon_png_path, format='PNG')
    print(f"Generated {icon_png_path} (512x512)")
    
    # 生成macOS图标（PNG格式）
    mac_icon_path = os.path.join(script_dir, 'mac-icon.png')
    mac_icon = generate_deskon_logo(1024)  # macOS需要更大的图标
    mac_icon.save(mac_icon_path, format='PNG')
    print(f"Generated {mac_icon_path} (1024x1024)")
    
    # 生成托盘图标（使用较小的尺寸）
    tray_icon_path = os.path.join(script_dir, 'tray-icon.ico')
    generate_ico_file(tray_icon_path, sizes=[16, 32, 48])
    
    # 生成Flutter应用图标
    flutter_icon_dir = os.path.join(script_dir, '..', 'flutter', 'windows', 'runner', 'resources')
    os.makedirs(flutter_icon_dir, exist_ok=True)
    flutter_icon_path = os.path.join(flutter_icon_dir, 'app_icon.ico')
    generate_ico_file(flutter_icon_path)
    
    # 生成Flutter assets中的图标（PNG和SVG作为fallback）
    flutter_assets_dir = os.path.join(script_dir, '..', 'flutter', 'assets')
    os.makedirs(flutter_assets_dir, exist_ok=True)
    flutter_icon_png = os.path.join(flutter_assets_dir, 'icon.png')
    icon_png.save(flutter_icon_png, format='PNG')
    print(f"Generated {flutter_icon_png}")
    
    print("All icons generated successfully!")

