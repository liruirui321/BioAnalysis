import re
import sys

def align_tree_ids(pep_file, tree_file, output_file):
    # 1. 读取 PEP 文件并提取所有的完整 ID
    full_ids = []
    with open(pep_file, 'r') as f:
        for line in f:
            if line.startswith('>'):
                # 提取 '>' 后面的完整 ID，按空格截断（如果你的 ID 里有空格的话）
                full_id = line.strip()[1:].split()[0]
                full_ids.append(full_id)

    # 2. 读取原始的 Tree 文件
    with open(tree_file, 'r') as f:
        tree_content = f.read()

    # 3. 定义一个安全的替换函数
    replace_count = 0
    skip_count = 0

    def replacer(match):
        nonlocal replace_count, skip_count
        prefix = match.group(1)   # 匹配 '(' 或 ','
        tree_id = match.group(2)  # 匹配树里的 ID
        suffix = match.group(3)   # 匹配 ':' (IQ-TREE 的分支长度前缀)

        # 如果树里的 ID 已经是个完整的 ID，保持原样
        if tree_id in full_ids:
            skip_count += 1
            return match.group(0)

        # 在 PEP 的完整 ID 列表中，寻找以树 ID 开头的序列
        matches = [fid for fid in full_ids if fid.startswith(tree_id)]

        if len(matches) == 1:
            # 找到唯一匹配，进行替换
            replace_count += 1
            return f"{prefix}{matches[0]}{suffix}"
        elif len(matches) > 1:
            # 找到多个匹配（说明前缀有歧义，比如 tree_id="Gene1", pep里有"Gene10", "Gene11"）
            print(f"⚠️ 警告: 树 ID '{tree_id}' 匹配到多个 PEP ID，跳过替换以防出错。")
            skip_count += 1
            return match.group(0)
        else:
            # 没找到匹配的 ID
            skip_count += 1
            return match.group(0)

    # 4. 使用正则安全匹配 Newick 格式的叶子节点
    # ([(,])      -> 匹配 '(' 或 ','
    # ([^:(),]+)  -> 匹配非控制字符的 ID 部分
    # (:)         -> 匹配后面的冒号
    new_tree_content = re.sub(r'([\(,])([^:\(\),]+)(:)', replacer, tree_content)

    # 5. 输出新的树文件
    with open(output_file, 'w') as f:
        f.write(new_tree_content)

    print("-" * 40)
    print(f"🎉 转换完成！")
    print(f"成功替换了 {replace_count} 个 ID。")
    print(f"跳过了 {skip_count} 个 ID（无需修改或未找到匹配）。")
    print(f"新的树文件已保存为: {output_file}")
    print("-" * 40)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("用法: python rename_tree.py <你的.pep文件> <你的.treefile> <输出的新树文件名>")
        sys.exit(1)
    align_tree_ids(sys.argv[1], sys.argv[2], sys.argv[3])
