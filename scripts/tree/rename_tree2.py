import re
import sys

# 核心大招：计算两个字符串从头开始，有多少个字符是完全一致的
def get_lcp_length(s1, s2):
    length = 0
    for c1, c2 in zip(s1, s2):
        if c1 == c2:
            length += 1
        else:
            break
    return length

def align_tree_ids(pep_file, tree_file, output_file):
    # 1. 读取 PEP 文件并提取所有的完整 ID
    full_ids = []
    with open(pep_file, 'r') as f:
        for line in f:
            if line.startswith('>'):
                full_ids.append(line.strip()[1:].split()[0])

    # 2. 读取原始的 Tree 文件
    with open(tree_file, 'r') as f:
        tree_content = f.read()

    replace_count = 0
    lcp_count = 0
    skip_count = 0

    def replacer(match):
        nonlocal replace_count, lcp_count, skip_count
        prefix = match.group(1)   
        tree_id = match.group(2)  
        suffix = match.group(3)   

        # 优先级 1：完美匹配，直接跳过
        if tree_id in full_ids:
            skip_count += 1
            return match.group(0)

        # 优先级 2：前缀包含匹配 (比如树里是简写，PEP里是全称)
        matches = [fid for fid in full_ids if fid.startswith(tree_id)]
        if len(matches) == 1:
            replace_count += 1
            return f"{prefix}{matches[0]}{suffix}"
        elif len(matches) > 1:
            skip_count += 1
            return match.group(0)

        # 优先级 3：智能前缀比对 (解决中间字符被吃掉或被替换的问题)
        max_lcp = 0
        candidates = []
        
        # 让树 ID 和所有的 PEP ID 去比对，寻找前半截重合度最高的那个
        for pep_id in full_ids:
            l = get_lcp_length(tree_id, pep_id)
            if l > max_lcp:
                max_lcp = l
                candidates = [pep_id]
            elif l == max_lcp and max_lcp > 0:
                # 记录出现平局的情况
                candidates.append(pep_id)

        # 判定条件：前缀至少匹配了 5 个字符（防止误判），且只有一个最佳候选人
        if max_lcp >= 5 and len(candidates) == 1:
            replace_count += 1
            lcp_count += 1
            return f"{prefix}{candidates[0]}{suffix}"

        # 匹配失败或有歧义
        skip_count += 1
        return match.group(0)

    # 4. 使用正则安全匹配
    new_tree_content = re.sub(r'([\(,])([^:\(\),]+)(:)', replacer, tree_content)

    # 5. 输出新的树文件
    with open(output_file, 'w') as f:
        f.write(new_tree_content)

    print("-" * 50)
    print(f"🎉 转换完成！")
    print(f"✅ 成功替换了 {replace_count} 个 ID。")
    print(f"⏭️ 跳过了 {skip_count} 个 ID。")
    print(f"📄 新的树文件已保存为: {output_file}")
    print("-" * 50)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("用法: python rename_tree_prefix.py <你的.pep文件> <你的.treefile> <输出的新树文件名>")
        sys.exit(1)
    align_tree_ids(sys.argv[1], sys.argv[2], sys.argv[3])
