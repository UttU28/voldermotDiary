def solution(paragraphs, aligns, width):
    result = []
    border = "*" * (width + 2)
    result.append(border)
    
    for i, paragraph in enumerate(paragraphs):
        align = aligns[i]
        current_line = []
        current_length = 0
        
        for word in paragraph:
            if current_line:
                potential_length = current_length + 1 + len(word)
            else:
                potential_length = len(word)
            
            if potential_length > width and current_line:
                line_text = " ".join(current_line)
                spaces_needed = width - len(line_text)
                
                if align == "LEFT":
                    line_text = line_text + " " * spaces_needed
                else:
                    line_text = " " * spaces_needed + line_text
                
                result.append("*" + line_text + "*")
                current_line = [word]
                current_length = len(word)
            else:
                current_line.append(word)
                current_length = potential_length
        
        if current_line:
            line_text = " ".join(current_line)
            spaces_needed = width - len(line_text)
            
            if align == "LEFT":
                line_text = line_text + " " * spaces_needed
            else:
                line_text = " " * spaces_needed + line_text
            
            result.append("*" + line_text + "*")
    
    result.append(border)
    return result


if __name__ == "__main__":
    paragraphs = [["hello", "world"], ["How", "are", "you", "doing"], ["Please look", "and align", "to right"]]
    aligns = ["LEFT", "RIGHT", "RIGHT"]
    width = 16
    
    result = solution(paragraphs, aligns, width)
    for line in result:
        print(line)
