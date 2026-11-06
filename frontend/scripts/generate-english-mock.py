#!/usr/bin/env python3
"""Build original, offline English Book 3 fixtures. No APIs or source-text extraction."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
BOOK_ID = "catalog_english_required_3"
UNITS = [
 {
  "name": "Festivals and Celebrations", "zh": "节日与庆祝", "place": "a neighbourhood lantern evening",
  "vocab": [("celebration", "庆祝活动；a community celebration"), ("tradition", "传统；keep a tradition alive"), ("decorate", "装饰；decorate the square with lanterns"), ("grateful", "感激的；be grateful for a neighbour's help"), ("gather", "聚集；gather around the table"), ("occasion", "时刻、场合；a special occasion")],
  "collocation": "decorate ... with ... / be grateful for ... / take part in ...",
  "grammar": "现在分词作定语和表语", "formula": "the lanterns hanging above us；The story is moving.",
  "grammar_text": "现在分词作定语时可以说明名词主动进行的动作：the children carrying lanterns 指正在提灯的孩子，carrying 与 children 是主动关系。短分词通常前置，较长的分词短语常放在名词后面；the lanterns hanging over the square 中 hanging over the square 修饰 lanterns。分词作表语还可说明事物的性质：The celebration is exciting. 不要把 exciting 与 excited 混淆，前者说活动使人兴奋，后者说人感到兴奋。现在分词形式本身不保证事件发生在说话的此刻，应结合主句时态和上下文判断。",
  "grammar_good": "The children carrying lanterns are gathering near the bridge.",
  "grammar_bad": "The children carried lanterns are gathering near the bridge.",
  "grammar_reason": "此处要用后置定语说明孩子主动提着灯笼，carrying lanterns 可以展开为 who are carrying lanterns；carried 不构成这里所需的主动修饰关系。",
  "dialogue": "Mia: Is the lantern evening only for people who live on this street?\nNoah: No. Everyone is welcome. We gather in the square at six.\nMia: Should I buy a new lantern?\nNoah: You do not have to. We are making lanterns from used paper so that less material is wasted.\nMia: What happens after the lights are switched on?\nNoah: Older neighbours tell stories, and children explain the pictures on their lanterns.\nMia: That sounds meaningful. I can bring paper and help clean the square afterwards.\nNoah: Great. The celebration matters because people do things together.",
  "reading_title": "A Lantern That Carried a Story",
  "reading": "On Friday afternoon, Lin found an old map in a drawer. Instead of buying colourful paper for the neighbourhood lantern evening, she used the map to cover a simple frame. She drew a small tree on one side and left the street names visible. At first she worried that her lantern would look less beautiful than the others.\n\nWhen the neighbours gathered in the square, an older woman recognised a street that no longer existed. She told the children about the shop where she had bought her first schoolbag. Other neighbours began to share their memories. Lin realised that the map had given them something to talk about.\n\nBy the end of the evening, the lantern was not the brightest object in the square, but several people had asked to see it. Lin wrote one sentence in her diary: a tradition stays alive when people add their own stories to it. The next morning, she helped collect the used paper and saved the frame for another year.",
  "reading_detail": "Lin used an old map because she wanted to reuse material; its visible street names later encouraged neighbours to share memories.",
  "reading_main": "Personal stories and shared participation can give an old celebration new meaning.",
  "reading_evidence": "recognised a street → shared memories → asked to see the lantern",
  "writing_title": "A Short Festival Diary",
  "writing": "Saturday, clear\n\nYesterday I joined our neighbourhood lantern evening for the first time. Before sunset, we put handmade lanterns around the square. Mine was covered with an old map, and I felt nervous when I placed it beside the colourful ones.\n\nThe most memorable moment came when a neighbour recognised a street name on my lantern. She told us a story about her childhood, and soon other people were sharing their memories. I had thought the evening would be mainly about lights, but the conversations made it special.\n\nAfterwards, we collected the paper and kept the frames for next year. I went home feeling grateful. A celebration can connect people when everyone brings something of their own.",
  "talk": "Host: What did you enjoy most about the lantern evening?\nGuest: I especially enjoyed the stories. The lantern made from a map reminded people of their old street.\nHost: Was anything different from what you expected?\nGuest: Yes. I expected a colourful show, but we spent more time talking than watching.\nHost: How did you feel at the end?\nGuest: I felt closer to my neighbours. Next year I would like to invite the new families on the street.\nHost: That is a thoughtful idea. Could you help design an invitation?\nGuest: Certainly. It should explain that visitors can bring a story as well as a lantern.",
  "project": "Design a small cultural display called 'One Object, One Story'. Choose a festival object, such as a paper lantern, and write a label of 60–80 words. Your label should name the object, describe how people use it, and explain a memory or value connected with it. Invite two classmates to check whether a visitor from another community could understand the label without extra background information. Keep a record of their questions and revise the wording. You may use drawings instead of buying objects. End your display with a question that encourages visitors to share their own traditions rather than rank different festivals.",
  "video": "Frame 1, 0–2 seconds: A plain paper lantern and an old map appear on a table. Caption: 'An ordinary object can carry a memory.'\nFrame 2, 2–4 seconds: The lantern is placed in a square. Neighbours point to a visible street name and begin a conversation. Caption: 'Stories connect generations.'\nFrame 3, 4–6 seconds: People collect the paper and keep the lantern frame. Caption: 'A living tradition can also change.'\nVoice-over: 'Look beyond the lights. Notice who joins the celebration, what they share, and how they care for the place afterwards.'",
  "scene_steps": ["准备可再用的灯笼", "分享街区故事", "保留传统并加入新意"],
  "mistake": "a traditional custom（传统习俗）中的 traditional 是形容词；tradition 是名词，不能直接写成 a tradition custom。",
  "inference": "Lin's worry changes into confidence because other people find meaning in her lantern, not because it wins a prize.",
  "assess": "The moving story told by the neighbour made the children feel moved. The lanterns hanging over the square looked simple but meaningful.",
  "workbook": "An exchange student is invited to a spring flower fair. Write a reply accepting the invitation, ask whether you should bring anything, and explain one tradition from your own community without claiming that everybody celebrates in the same way. In the reply, use one -ing phrase to describe people or objects, such as the families walking along the river. Then replace a vague adjective such as nice with a more precise one, such as welcoming or memorable. Check that the invitation gives a time and a meeting place."
 },
 {
  "name": "Morals and Virtues", "zh": "道德与美德", "place": "a school library and a community reading room",
  "vocab": [("responsibility", "责任；take responsibility for a mistake"), ("patient", "耐心的；be patient with a young reader"), ("honest", "诚实的；give an honest explanation"), ("respect", "尊重；show respect for another person's choice"), ("assist", "帮助；assist a visitor with the catalogue"), ("choice", "选择；make a thoughtful choice")],
  "collocation": "take responsibility for ... / be patient with ... / offer to help ...",
  "grammar": "现在分词作宾语补足语和状语", "formula": "I saw a reader waiting. Seeing the queue, I offered to help.",
  "grammar_text": "现在分词作宾语补足语时补充说明宾语正在进行的动作：I saw a reader waiting outside. 中 a reader 是 waiting 的逻辑主语。现在分词作状语时，逻辑主语通常与主句主语一致：Seeing the long queue, Maya opened another desk. 表示 Maya 先看见队伍，再采取行动。不能写成 Seeing the queue, another desk was opened，因为这样主句主语与 seeing 的执行者不一致。分词短语可以表达时间、原因或伴随关系，具体关系要由上下文确定，不能把每一个 -ing 都机械译成“正在”。",
  "grammar_good": "Seeing an older visitor waiting, Maya offered to find a seat for him.",
  "grammar_bad": "Seeing an older visitor waiting, a seat was found by Maya.",
  "grammar_reason": "看到来访者的人应与主句主语一致。以 Maya 作主语才能让 seeing 的逻辑主语清楚；被动句以 a seat 作主语会形成悬垂分词。",
  "dialogue": "Maya: We have one free seat, but two people are waiting. What should we do?\nEli: We could ask whether either person needs the seat urgently.\nMaya: I do not want to make assumptions from their appearance.\nEli: Then let us explain the situation and ask them politely.\nMaya: Good idea. We can also bring a chair from the next room.\nEli: I will check with the librarian first.\nMaya: Thank you. Making a fair choice sometimes means finding more information, not deciding faster.\nEli: And if we make a mistake, we should explain it and correct it.",
  "reading_title": "The Name on the Library Card",
  "reading": "Maya was helping at the community reading room when she found a small bag under a chair. Inside were a library card and several coins. A classmate suggested leaving it on the information desk and returning to their own work. Maya agreed that the bag should stay with the librarian, but she also asked how its owner could be contacted.\n\nThe card belonged to a visitor who used large-print books. Maya did not announce the visitor's name across the room. Instead, she gave the bag to the librarian, who used the library's normal lost-property procedure. Later that afternoon, the visitor came back and collected it.\n\nNo one gave Maya a prize. She still had shelves to tidy, and she had missed part of her break. However, she understood why the quiet procedure mattered: helping someone should also respect that person's privacy. At the end of the day, she wrote two reminders for the volunteer team: look for a useful action, and consider how that action affects the person being helped.",
  "reading_detail": "Maya handed the bag to the librarian and followed the normal lost-property procedure instead of announcing the owner's name publicly.",
  "reading_main": "A helpful action should combine responsibility with respect for the person being helped.",
  "reading_evidence": "found the bag → asked about the procedure → avoided a public announcement",
  "writing_title": "A Small Choice in the Reading Room",
  "writing": "At first, the problem seemed simple: a visitor had left a bag under a chair. We could put it on a desk and forget about it. Maya chose to ask the librarian how lost property was handled. She wanted the owner to get it back without having personal details announced to everyone.\n\nHer choice cost a few minutes of her break, but it protected the visitor's privacy and kept the bag in the right place. The action was quiet, and there was no reward. That is why I find the story meaningful. Responsibility is often shown through ordinary decisions.\n\nIf I faced a similar situation, I would seek a responsible adult's help and follow the agreed procedure rather than make a public display of being helpful.",
  "talk": "Interviewer: Did you feel proud when the visitor collected the bag?\nMaya: I felt relieved. I had been worried that we might make the problem worse.\nInterviewer: What helped you decide what to do?\nMaya: I asked the librarian instead of guessing. I also thought about the visitor's privacy.\nInterviewer: Was your classmate's first suggestion unkind?\nMaya: Not at all. We both wanted to help. We needed to think through the next step.\nInterviewer: What will you do differently next time?\nMaya: I will learn the reading room's procedures before my shift begins, so I can respond more calmly.",
  "project": "Create a volunteer decision card for a reading room. Use three situations: a lost item, a long queue, and a visitor who cannot find a book. For each situation, write one respectful question, one practical action, and one person you can ask for help. Do not include real visitors' names or private details. Test the card with a partner acting as a new volunteer. Ask the partner to explain why the action helps and whether it could create a new problem. Revise the card so that it supports judgment rather than pretending that one slogan can solve every situation.",
  "video": "Frame 1, 0–2 seconds: A volunteer notices a bag under a library chair. Caption: 'Notice a need.'\nFrame 2, 2–4 seconds: She speaks quietly to the librarian and places the bag in the lost-property area. Caption: 'Choose a responsible action.'\nFrame 3, 4–6 seconds: The owner receives the bag through the library's usual procedure. Caption: 'Help with respect.'\nVoice-over: 'A kind intention is a beginning. Ask what action is useful, who should be involved, and how the other person will be affected.'",
  "scene_steps": ["发现他人需要", "询问并选择行动", "帮助也尊重对方"],
  "mistake": "patient 作“耐心的”时常接 with：be patient with a young reader；patience 才是“耐心”这个名词。",
  "inference": "Maya values a respectful procedure more than public praise; the text explicitly says that she receives no prize.",
  "assess": "Waiting outside the reading room, the visitor saw Maya bringing an extra chair. She found the librarian checking the lost-property record.",
  "workbook": "Write a short response to this dilemma: you promised to help prepare a class display, but a friend asks you to leave early. State the promise, describe the competing request, and propose a respectful solution. Use a participle clause only when its logical subject matches the main-clause subject. For example, Remembering my promise, I explained why I needed to stay is clear. Explain how keeping a promise differs from refusing every request for help, and add one question you would ask before deciding."
 },
 {
  "name": "Diverse Cultures", "zh": "多样文化", "place": "a shared neighbourhood market",
  "vocab": [("diverse", "多样的；a diverse neighbourhood"), ("settle", "定居；settle in a new city"), ("adapt", "适应、改编；adapt a family recipe"), ("local", "当地的；local ingredients"), ("exchange", "交流；an exchange of ideas"), ("heritage", "传承；a family's cultural heritage")],
  "collocation": "settle in ... / adapt ... to ... / learn about ... through ...",
  "grammar": "语境明确时的省略", "formula": "If possible, ask first. Want to try some? — I'd love to.",
  "grammar_text": "省略的作用是避免重复，并让对话自然，但被省略的部分必须能由语境恢复。If possible, ask the cook about the recipe. 中 if possible 可理解为 if it is possible。对方问 Would you like to try the soup? 时，回答 I'd love to. 可以省去已经明确的 try the soup；to 往往需要保留。Want to try some? 在口语中省去 Do you，不宜直接照搬到所有正式书面语。省略不能任意删除主干成分，读者如果无法判断缺少什么，就应把句子写完整。判断省略时先恢复完整表达，再检查主谓和时态是否仍然一致。",
  "grammar_good": "If possible, ask the stallholder how the recipe has changed.",
  "grammar_bad": "If possibility, ask the stallholder how the recipe has changed.",
  "grammar_reason": "省略的是 it is，不是把形容词 possible 改成名词 possibility；恢复完整形式为 If it is possible。",
  "dialogue": "Sara: This soup smells different from the one I tried last week. Is it a traditional recipe?\nBen: It began with my grandmother's recipe, but we use vegetables grown near this town.\nSara: So the recipe has changed?\nBen: Yes. My family adapted it after moving here. Some ingredients were difficult to find.\nSara: May I ask your grandmother about it?\nBen: Of course, if she is free. Would you like to taste a little first?\nSara: I would love to. I will ask before taking a photograph of the stall.\nBen: Thank you. A conversation tells you more than a quick picture.",
  "reading_title": "A Market with More Than One Story",
  "reading": "When Sara moved to a new neighbourhood, she first visited its Saturday market to buy vegetables. The stalls displayed dishes with names she did not know. She was tempted to take photographs and write that the market was a perfect picture of one culture. Then she spoke to Ben, whose family sold soup.\n\nBen explained that his grandmother had brought the recipe from another region. After the family settled in the town, they began using local beans because the original kind was hard to find. A neighbour suggested a different herb, and customers asked for a less salty version. The soup had a history, but it was not unchanged.\n\nSara visited three more stalls and heard three different stories about migration, work and friendship. In her class presentation, she did not claim that one dish represented everyone from a place. She described what she had observed and quoted the stallholders with their permission. The market helped her see cultural exchange as a continuing conversation, not a collection of fixed labels.",
  "reading_detail": "Ben's family adapted the soup with local beans and a neighbour's suggested herb after moving to the town.",
  "reading_main": "Cultural practices can keep their history while changing through migration and everyday exchange.",
  "reading_evidence": "grandmother's recipe → local ingredients → neighbours' suggestions",
  "writing_title": "An Introduction to Our Saturday Market",
  "writing": "Our Saturday market stands beside the old station. It is small enough to walk through in ten minutes, but visitors should allow time for conversations. You can buy vegetables, try different dishes and hear how families have adapted recipes after moving here.\n\nOne stall sells a soup based on the owner's grandmother's recipe. Local beans have replaced an ingredient that was difficult to find, and a neighbour suggested the herb now used in it. This is only one family's experience, so it should not be taken as a description of an entire culture.\n\nIf you visit, ask before taking photographs and listen to the people behind the stalls. The market is interesting because its stories are still developing.",
  "talk": "Guide: What surprised you at the market?\nVisitor: I expected recipes to stay exactly the same. Ben explained why his family had changed theirs.\nGuide: Does changing a recipe mean losing its history?\nVisitor: Not necessarily. The family still knows where it came from. The changes also tell a story about their new home.\nGuide: How could you describe the market fairly?\nVisitor: I could describe particular conversations and say who shared each idea, instead of making claims about everyone.\nGuide: Would you visit again?\nVisitor: Certainly. I would like to ask how the market changes with the seasons.",
  "project": "Make a neighbourhood culture map using three places you can describe from observation or from fictional interviews supplied in class. For each place, record an activity, one person's explanation, and one change over time. Separate an observation such as 'the stall sells bean soup' from an interpretation such as 'the recipe shows adaptation'. Use permission-based, anonymous quotations if you interview classmates. Add a note explaining that three examples cannot represent an entire community. Present a question for further inquiry, such as how customers have influenced the market, rather than ending with a stereotype about a group.",
  "video": "Frame 1, 0–2 seconds: A recipe card sits beside ingredients from a new town. Caption: 'A recipe has a history.'\nFrame 2, 2–4 seconds: A cook replaces one ingredient and talks with a neighbour. Caption: 'Everyday exchange brings change.'\nFrame 3, 4–6 seconds: Visitors listen to several stallholders instead of placing one label on the whole market. Caption: 'Listen to more than one story.'\nVoice-over: 'Culture is shared, but people do not all have the same experience. Describe specific voices and notice how practices develop.'",
  "scene_steps": ["了解原有故事", "观察交流与改变", "避免单一标签"],
  "mistake": "culture 是名词，cultural 是形容词；写 cultural exchange，而不是把 culture exchange 当成这里的标准搭配。",
  "inference": "Sara changes her presentation plan because individual stories show that the market cannot be reduced to one fixed cultural label.",
  "assess": "Would you like to hear the story? — I'd love to. If possible, we will speak to several stallholders before writing our report.",
  "workbook": "Prepare a short introduction for an exchange student's walking tour. Describe two places with specific observations and explain one change over time. Use a full sentence when the meaning would otherwise be unclear; use an elliptical response such as I'd love to only when its missing verb phrase is recoverable from the question. Add one sentence that limits your claim, for example These interviews describe three families, not every resident. Finish with a question that invites the visitor's own perspective."
 },
 {
  "name": "Space Exploration", "zh": "太空探索", "place": "a school satellite-design discussion",
  "vocab": [("explore", "探索；explore a scientific question"), ("orbit", "轨道、环绕运行；a satellite in orbit"), ("launch", "发射；prepare for a launch"), ("mission", "任务；the aim of a mission"), ("evidence", "证据；collect evidence before drawing a conclusion"), ("reliable", "可靠的；a reliable power supply")],
  "collocation": "in orbit / be designed to ... / collect data on ...",
  "grammar": "不定式作定语和目的状语", "formula": "a satellite to observe clouds；We test it to improve reliability.",
  "grammar_text": "不定式可以作后置定语，说明名词的用途、任务或有待完成的动作：a satellite to observe clouds 表示用于观测云层的卫星，a problem to solve 表示需要解决的问题。它也可作目的状语：The team repeated the test to improve reliability. 中 to improve 回答重复测试的目的。不要把目的与已实现的结果混为一谈，designed to observe 说明设计目标，不等于已经获得数据。first、last 或序数词修饰名词时也常用不定式，如 the first student to notice the fault。解释句子时先判断不定式修饰哪个词，再判断它表达用途还是目的。",
  "grammar_good": "The team tested the power system to find possible faults.",
  "grammar_bad": "The team tested the power system for find possible faults.",
  "grammar_reason": "表达“为了发现问题”的目的时用 to find。介词 for 后不能直接接动词原形 find，另一种结构可写 for finding，但本句目的状语用不定式更直接。",
  "dialogue": "Leo: Our class satellite needs a clear mission. What should it observe?\nAva: We could design it to compare cloud cover over the same area at different times.\nLeo: Then do we choose the camera first?\nAva: We should discuss the question and the data we need before choosing equipment.\nLeo: What about power?\nAva: The model must show how the instruments receive energy and how stored energy is used when light is unavailable.\nLeo: We cannot test it in space.\nAva: True. We can explain the limits of our classroom model and test one part of the design on the ground.",
  "reading_title": "A Mission Small Enough to Explain",
  "reading": "Leo's class was asked to design a model satellite, not to launch one. At first, the group drew a large spacecraft covered with instruments. Their teacher asked a simple question: what evidence would those instruments collect? The group could not give a clear answer.\n\nThey began again with a smaller mission: compare cloud cover over one area at different times. This question helped them decide what kind of images they would need. They also added a power diagram showing a solar panel, a battery and the instruments. The battery mattered because the instruments might need energy when direct light was unavailable.\n\nDuring the presentation, Leo explained what the classroom model could and could not show. It could make the mission and energy pathway visible, but it could not prove that real equipment would survive in orbit. The class preferred the second design because each part had a reason to be there. Leo learned that a useful scientific proposal starts with a question and a plan for evidence, not simply with impressive-looking technology.",
  "reading_detail": "The group chose to compare cloud cover over one area at different times and included a battery for times when direct light was unavailable.",
  "reading_main": "A clear scientific question should guide the choice of instruments, tests and claims in a model mission.",
  "reading_evidence": "unclear instrument list → cloud-cover question → power diagram → limits of the model",
  "writing_title": "Why Our Model Needs a Clear Mission",
  "writing": "Our model satellite is designed to compare cloud cover over one area at different times. We chose this mission because it gives us a question that every part of the model can help explain. A camera represents the instrument used to collect images, while the power diagram shows a solar panel and a battery.\n\nThe model is useful for communication. It helps our audience follow the link between a question, the required data and the equipment. However, a classroom model cannot show that the equipment would survive a real launch or operate reliably in orbit.\n\nFor this reason, we describe our work as a design explanation. We will improve it by asking classmates whether the energy pathway and the limits are easy to understand.",
  "talk": "Presenter: Our satellite model is designed to compare cloud cover.\nAudience: Why did you remove some of the instruments from your first drawing?\nPresenter: They did not help answer our question. We wanted each part to have a clear purpose.\nAudience: What is the battery for?\nPresenter: It represents stored energy for times when direct light is unavailable.\nAudience: Does the model prove that the satellite would work in orbit?\nPresenter: No. It explains a design. Real operation would require many tests that our classroom activity cannot provide.\nAudience: What will you improve next?\nPresenter: We will make the link between the mission and the required images clearer.",
  "project": "Create a mission board for a fictional observation satellite. Give it one research question, list the data needed to answer that question, and draw an energy pathway from a source through storage to an instrument. Write a 90-second explanation using infinitives of purpose, such as We include a battery to store energy. Ask another group to identify any component whose purpose is unclear. Add two limitations of the classroom model. This is a paper design and communication task; it does not involve building or launching a flying device. Revise the board until the scientific question is more prominent than the decoration.",
  "video": "Frame 1, 0–2 seconds: A question appears above a sketch of clouds. Caption: 'What do we want to find out?'\nFrame 2, 2–4 seconds: Arrows connect a camera, collected images and the question. Caption: 'Choose evidence before equipment.'\nFrame 3, 4–6 seconds: A solar panel, battery and instrument form an energy pathway. Caption: 'Explain functions and limits.'\nVoice-over: 'A model helps us explain a mission. It does not replace the tests required for real equipment in space. Start with a question, and give each component a purpose.'",
  "scene_steps": ["提出观测问题", "确定证据和仪器", "解释能源与模型局限"],
  "mistake": "evidence 通常作不可数名词；写 collect evidence 或 a piece of evidence，不写 an evidence 来表示一条证据。",
  "inference": "The second design is clearer because its parts answer a defined question; the text does not claim that fewer instruments are always better for real missions.",
  "assess": "The first student to notice the fault asked for another test. The team drew a diagram to explain how the battery supplied the instrument.",
  "workbook": "Write a mission proposal for a fictional weather-observation model. Include one question, one type of data and one limitation. Underline each infinitive and label it as a modifier of a noun or as an expression of purpose. In the phrase a device to measure temperature, identify device as the modified noun. In We repeat the test to check the reading, explain that the infinitive gives the reason for repeating the test. Avoid claiming that a classroom diagram proves that real hardware will work in orbit."
 },
 {
  "name": "The Value of Money", "zh": "金钱的价值", "place": "a neighbourhood repair corner",
  "vocab": [("value", "价值；the value of a useful skill"), ("afford", "负担得起；afford to replace a bag"), ("earn", "挣得；earn money through work"), ("generous", "慷慨的；a generous offer of time"), ("patiently", "耐心地；explain a repair patiently"), ("trust", "信任；build trust by keeping a promise")],
  "collocation": "afford to do ... / keep a promise / in return for ...",
  "grammar": "情态动词与过去将来时", "formula": "It may be useful. She said she would repair it on Saturday.",
  "grammar_text": "情态动词要结合语境解释：may 可以表示不确定的可能性，should 常用于建议或应该承担的责任，must 可以表达强烈要求，也可以基于证据作较有把握的推测。不要把 may 一律译成“允许”，也不要把 must 一律当作命令。过去将来时常从过去的时间点谈之后的安排：Nora said she would repair the bag on Saturday. would repair 表示她当时说到的后续行动，不自动保证后来真的完成。写故事时应区分人物的计划、推测和已经发生的事件，必要时再用一般过去时交代结果。",
  "grammar_good": "Nora said she would repair the bag on Saturday, and she kept her promise.",
  "grammar_bad": "Nora said she will repaired the bag on Saturday.",
  "grammar_reason": "从过去的 said 看后续计划可用 would repair；would 后接动词原形。will repaired 同时混用了情态形式与过去式。",
  "dialogue": "Sam: My bag is torn, but I cannot afford to replace it this week.\nNora: The repair corner may be able to help. You should ask what can be repaired before buying another one.\nSam: Do they charge for everything?\nNora: They explain the options first. Sometimes a small repair needs only a few minutes.\nSam: I do not know how to sew.\nNora: You can still contribute. Last month I helped organise the tools in return for a lesson.\nSam: Then I will ask whether they need help setting up.\nNora: Good. Money pays for some things, but time, skills and trust also have value.",
  "reading_title": "A Bag, a Promise and a Useful Skill",
  "reading": "Sam brought a torn bag to the neighbourhood repair corner because he could not afford a new one that week. He expected a quick repair and a price. Instead, Nora asked how the bag had been damaged and whether he wanted to learn a simple way to mend it.\n\nNora said she would repair the handle on Saturday if Sam could help arrange the tools before the session. She did not pretend that every broken object could be saved. She explained the weak part of the handle and showed him how to check it after the repair. Sam listened patiently, then helped another visitor find the right table.\n\nBy the end of the session, he had a usable bag and one new skill. He also understood that the corner depended on people keeping their promises. His help had not replaced all the materials or expertise needed for the repair, but it had contributed to a shared activity. In his school reflection, Sam wrote that money was important without being the only measure of value. Time, knowledge and trust made the afternoon work as well.",
  "reading_detail": "Nora promised to repair the handle on Saturday, and Sam helped arrange the tools before the session.",
  "reading_main": "Money matters, but shared time, useful skills and reliable promises can create value as well.",
  "reading_evidence": "could not afford a new bag → offered help → learned a skill → reflected on trust",
  "writing_title": "At the Repair Corner: A Short Scene",
  "writing": "Scene: A table in the community room. A torn bag lies between Sam and Nora.\n\nSam: I thought I had to buy a new one.\nNora: You may have another option. This handle can be repaired, but it will still need careful use.\nSam: I cannot pay much today.\nNora: Let us discuss the materials first. You could also help arrange the tools before Saturday's session.\nSam: I can do that. Will you show me what to check afterwards?\nNora: Certainly. A repair is more useful when you understand it.\n\nSam picks up a list of tools. He places the bag beside the list rather than throwing it away. The scene ends with a plan that both characters can explain.",
  "talk": "Viewer: At the beginning, Sam looks worried. What detail suggests that?\nPartner: He holds the torn bag and asks whether he must buy another one immediately.\nViewer: Does Nora say that money is unimportant?\nPartner: No. She discusses the materials and the repair options. She also values Sam's time and willingness to learn.\nViewer: What does her promise tell us?\nPartner: She says she will repair the handle on Saturday, and later the story shows that she does so.\nViewer: How could we perform the scene without exaggeration?\nPartner: We could use pauses and small actions, such as pointing to the weak handle, instead of making the characters deliver long speeches.",
  "project": "Write and perform a two-minute scene about an object that can be repaired, shared or replaced. Give the characters different priorities, such as cost, convenience and sentimental value. Include one uncertain suggestion with may, one recommendation with should, and one report of a past promise with would. Add stage directions that show a change in attitude through action. After performing, ask the audience what each character valued and which lines support that interpretation. Revise any sentence that sounds like a general slogan rather than something the character would naturally say in that situation.",
  "video": "Frame 1, 0–2 seconds: Sam looks at a torn bag and a price label. Caption: 'Price is one kind of information.'\nFrame 2, 2–4 seconds: Nora points to the handle and explains a repair. Sam arranges tools. Caption: 'Time and skills also contribute.'\nFrame 3, 4–6 seconds: Sam tests the repaired handle and thanks the group. Caption: 'Promises build trust.'\nVoice-over: 'The scene does not say that money is useless. It asks us to notice other forms of value that make cooperation possible.'",
  "scene_steps": ["比较价格与需要", "投入时间和技能", "守约建立信任"],
  "mistake": "afford 后常接名词或 to do：cannot afford a new bag / cannot afford to replace it；不要写 afford replacing it 作为这里的标准表达。",
  "inference": "Sam's contribution matters without making the repair free of all costs; the story mentions both materials and expertise.",
  "assess": "Nora said she would explain the repair on Saturday. Sam thought the bag might be useful for another year and decided to keep it.",
  "workbook": "Write a short scene in which two classmates decide what to do with an old bicycle helmet used only as a display prop. Focus on the characters' values and dialogue rather than giving safety or financial advice. Include a past promise reported with would and distinguish that promise from what actually happened later. Use a stage direction to reveal hesitation, such as Alex checks the label before speaking. End with a decision supported by the characters' reasons, not with a statement that money never matters."
 }
]

# Evidence and checks are tied to the actual section script, not borrowed from a reading.
LISTENING_DETAILS = [
    "The lantern evening is open to everyone, starts at six and uses lanterns made from used paper.",
    "The volunteers plan to ask visitors politely and check with the librarian before bringing another chair.",
    "Ben says his family adapted his grandmother's soup with local vegetables, and Sara plans to ask before taking a photograph.",
    "The team will define its cloud-cover question and required data before choosing equipment.",
    "Nora suggests asking about repair options first, and Sam plans to offer help setting up."
]
TALKING_DETAILS = [
    "The guest enjoyed the neighbours' stories and would like to invite new families next year.",
    "Maya says she asked the librarian, considered the visitor's privacy and wants to learn procedures before her next shift.",
    "The visitor says a changing recipe can keep its history and plans to describe particular conversations rather than everyone.",
    "The presenter explains that the battery represents stored energy and the classroom model does not prove real operation in orbit.",
    "The partners say that Nora discusses repair options and materials while also valuing Sam's time and willingness to learn."
]
LISTENING_INFERENCES = [
    "Noah explains both the practical arrangement and the reason for reusing paper; Mia's offer to help follows that explanation.",
    "Maya and Eli do not claim to know the waiting visitors' needs; they propose a polite question and a practical way to add a seat.",
    "Ben treats a changing recipe as a family practice connected with a new place, and Sara chooses to ask rather than assume.",
    "Ava prioritises a question and the data it requires over an impressive list of equipment; the class design remains a model.",
    "Nora presents repair as an option to investigate, and Sam offers useful help rather than claiming that all repairs have no cost."
]
TALKING_INFERENCES = [
    "The guest contrasts an expected colourful show with an actual evening of stories and conversations; inviting new families is a future idea.",
    "Maya's answer separates kind intentions from the need to choose a respectful procedure, and she does not blame her classmate's character.",
    "The visitor explains that a recipe can change while keeping a known history, and specific conversations are more careful evidence than claims about everyone.",
    "The presenter distinguishes the battery's intended function from proof that real equipment will operate in orbit.",
    "The partners interpret Nora's practical repair discussion without claiming that money is unimportant; actions and pauses can reveal the characters' changing priorities."
]
LISTENING_PRACTICE = [
    "Mia: I can come at six, but my friend will arrive a little later. Is that all right?\nNoah: Yes. Everyone is welcome. Could you meet her at the entrance so she knows where to go?\nMia: Certainly. We can both bring used paper.\nNoah: Thank you. The group making lanterns will show you where the spare frames are.\nMia: Then we will join the work before listening to the neighbours' stories.",
    "Maya: The librarian says we may bring one more chair. Could you check whether the doorway is clear?\nEli: Of course. I will put the chair beside the table, not in front of the door.\nMaya: Thank you. I will ask the visitors what would be most useful.\nEli: That gives them a chance to explain their needs.\nMaya: Yes. We can offer help without deciding everything for them.",
    "Sara: I would like to describe your soup in my class report. What should I explain first?\nBen: Please explain that it is one family's recipe, not a dish that everybody makes in the same way.\nSara: May I mention how you changed the vegetables after moving here?\nBen: Yes. That change is part of our story.\nSara: Thank you. I will check your explanation before I write my final paragraph.",
    "Leo: If our model could answer only one question, which question would we choose?\nAva: We would compare cloud cover over the same area at different times.\nLeo: Then we need images that can be compared.\nAva: Exactly. The camera has a purpose because of the data we need.\nLeo: I will also label the battery.\nAva: Good. Explain its intended function, and say that the drawing is not a real-space test.",
    "Sam: I have asked about the repair. They can explain the materials on Saturday.\nNora: Then you can decide whether the option suits your needs.\nSam: I have also offered to help arrange the tables.\nNora: That sounds useful. Please ask where the tools should go before moving them.\nSam: I will. I want to learn a skill and keep my promise to help.\nNora: Both of those can contribute to the afternoon."
]

JUDGMENTS = [
 [
  ("本单元听说对话中的灯笼晚会只允许本街道居民参加。", "错误", "Noah 明确说 Everyone is welcome，任何人都欢迎参加。"),
  ("原创阅读中，旧地图上的街名引出了邻居们的回忆。", "正确", "An older woman recognised a street，并由此讲述童年经历。"),
  ("the children carrying lanterns 中 carrying lanterns 说明孩子主动提着灯笼。", "正确", "carrying 与 children 是主动关系，分词短语作后置定语。"),
  ("谈话中的来宾原以为活动主要是一场灯光展示，后来更喜欢大家分享故事。", "正确", "来宾对比了原来的 colourful show 预期与更多的 talking。"),
  ("节日日记范文只罗列装饰品，没有写人物感受的变化。", "错误", "范文写到起初 nervous，最后 feeling grateful，感受随事件变化。"),
  ("The story is exciting. 中 exciting 描述故事使人兴奋的性质。", "正确", "exciting 描述事物性质；excited 常描述人的感受。"),
  ("One Object, One Story 项目要求比较不同节日谁更优越。", "错误", "任务以物品、记忆和交流为重点，结尾邀请分享传统而不作排名。"),
  ("灯笼短片最后保留框架，说明传统可以与可再用材料的选择结合。", "正确", "第三幅画面收集纸张并保留框架，与 living tradition can also change 呼应。")
 ],
 [
  ("座位对话中的志愿者决定只凭外表判断谁更需要座位。", "错误", "Maya 明确说不想从 appearance 作假设，而是解释情况并礼貌询问。"),
  ("Maya 在原创阅读中通过图书馆的失物流程归还物品，同时考虑失主隐私。", "正确", "她把包交给管理员而没有在房间里大声宣布姓名。"),
  ("Seeing the queue, Maya offered to help. 中看到队伍的人是 Maya。", "正确", "分词短语的逻辑主语应与主句主语 Maya 一致。"),
  ("Maya 认为同学最初的建议一定出于不友善。", "错误", "她说 Not at all. We both wanted to help，双方需要进一步考虑做法。"),
  ("本节短文认为责任只体现在获得公开奖励的行动中。", "错误", "范文强调 quiet choice 与 ordinary decisions，没有奖励也能表现责任。"),
  ("patient 是“耐心的”，patience 是“耐心”这个名词。", "正确", "be patient with ... 与 show patience 使用不同词性。"),
  ("志愿者决策卡应记录真实来访者的姓名和私人细节。", "错误", "项目明确不使用真实来访者姓名或私人细节，只写情境、问题和行动。"),
  ("失物短片把“发现需要—负责任行动—尊重对方”连成一条路线。", "正确", "三个字幕分别对应 Notice a need、Choose a responsible action、Help with respect。")
 ],
 [
  ("Ben 在听说对话中说食谱从未因迁居而改变。", "错误", "他说明使用本地蔬菜，家人在迁居后 adapted the recipe。"),
  ("Sara 最后认为一个摊位的一道菜就能代表某个地方的所有人。", "错误", "阅读结尾明确说她没有把一道菜当作所有人的代表。"),
  ("If possible 可以恢复为 If it is possible。", "正确", "省略的是可由语境恢复的主语和 be 动词。"),
  ("交流对话中的来访者认为食谱变化不一定意味着失去历史。", "正确", "来访者说 Not necessarily，并说明家人仍知道食谱从何而来。"),
  ("市场介绍范文提醒读者，一家人的经历不应代表整个文化。", "正确", "范文写 This is only one family's experience 并限制概括范围。"),
  ("cultural exchange 中 cultural 是修饰 exchange 的形容词。", "正确", "culture 为名词；本搭配用形容词 cultural。"),
  ("文化地图应区分观察到的活动与小组对其意义的解释。", "正确", "任务要求分开记录 observation 与 interpretation。"),
  ("市场短片鼓励只听一种声音，就给整个社区贴固定标签。", "错误", "末幅字幕为 Listen to more than one story，强调多种具体经历。")
 ],
 [
  ("卫星设计对话建议先买齐仪器，再考虑科学问题。", "错误", "Ava 说先讨论 question 和 data，再选 equipment。"),
  ("原创阅读中的课堂模型能证明真实卫星一定能在轨道上工作。", "错误", "文章明确区分设计解释与真实运行所需的测试。"),
  ("The team tested it to find faults. 中 to find faults 表示测试目的。", "正确", "它回答为什么进行测试，而不是陈述故障已经被发现。"),
  ("展示对话用电池表示直射光不可用时所需的储能。", "正确", "Presenter 解释 battery represents stored energy when direct light is unavailable。"),
  ("写作范文把模型描述为设计解释，而不冒充真实空间验证。", "正确", "文中说 design explanation，并列明真实发射和在轨运行的限制。"),
  ("a piece of evidence 可以表示一条证据。", "正确", "evidence 通常不可数，可用 a piece of evidence 表达一条证据。"),
  ("任务板只需要装饰吸引人，不必交代每个部件的用途。", "错误", "项目要求 question、data、energy pathway，并检查不清楚的部件用途。"),
  ("卫星短片先提出问题，再连接仪器、数据和能源路径。", "正确", "三幅分镜以 question 开头，随后说明 evidence、equipment 和 functions。")
 ],
 [
  ("修理角听说对话认为 Sam 只能立即买一个新包。", "错误", "Nora 建议先询问修理可能性，Sam 也准备提供布置场地的帮助。"),
  ("Sam 的故事既提到材料和专业技能，也提到时间与信任的价值。", "正确", "末段明确承认材料和专业知识，并讨论time、knowledge和trust。"),
  ("She said she would repair it. 单凭这一句就能确认修理后来已经完成。", "错误", "would repair 报告过去说到的后续打算，结果需要其他句子交代。"),
  ("观看讨论中的两位同学说，Nora 也考虑了材料和实际修理选项。", "正确", "他们没有说金钱完全不重要，而是同时讨论时间与技能。"),
  ("本节剧本用拿起工具清单的动作，展示人物开始参与共同计划。", "正确", "结尾 Sam picks up a list of tools，把态度变化放进行动而不是口号。"),
  ("afford to replace 是本单元可使用的动词搭配。", "正确", "afford 后可以接 to do，表示负担得起做某事。"),
  ("本节表演任务要求每个角色有不同考虑，并用具体台词说明理由。", "正确", "项目列出 cost、convenience、sentimental value，并要求自然对话。"),
  ("修理短片的主题是 money is useless。", "错误", "旁白明确说并非金钱无用，而是还应看见促成合作的其他价值。")
 ]
]

SECTIONS = ["Listening and Speaking", "Reading and Thinking", "Discovering Useful Structures", "Listening and Talking", "Reading for Writing", "Assessing Your Progress", "Project", "Video Time"]

def block(kind, title, content):
    return {"block_type": kind, "title": title, "content": content}

def quiz(kind, prompt, choices, answer, explanation, concept):
    return dict(question_type=kind, prompt=prompt, choices=choices, answer=answer, explanation=explanation, concept=concept)

def judgement(prompt, answer, explanation, concept):
    return quiz("judgment",prompt,["正确","错误"],answer,explanation,concept)

def cards(u, section, key_sentence, task):
    v = u['vocab'][(section-1)%6]
    return [
      {"front": f"{v[0]} 在本单元语境中怎样理解？", "back": v[1], "concept": v[0]},
      {"front": f"围绕 {u['zh']} 可使用哪些搭配？", "back": u['collocation'], "concept": "主题搭配"},
      {"front": f"{u['grammar']} 的核心用法是什么？", "back": u['grammar_text'].split('。')[0]+'。例句：'+u['grammar_good'], "concept": u['grammar']},
      {"front": "如何用本节示例表达一个完整意思？", "back": key_sentence, "concept": SECTIONS[section-1]},
      {"front": "本单元有哪些容易混淆的表达？", "back": u['mistake'], "concept": "易错辨析"},
      {"front": f"怎样把本节的语言用于新的 {u['zh']} 情境？", "back": task, "concept": "主题迁移"}
    ]

def section_topic(unit_index, section, chapter_id):
    u=UNITS[unit_index]
    listening_detail=LISTENING_DETAILS[unit_index]
    talking_detail=TALKING_DETAILS[unit_index]
    subject=u['zh']
    theme=u['name']
    method = {
      1: "听力先抓场景、说话人关系与交谈目的，再记录能区分选项的细节。阅读下面的原创对话时，可以先遮住文本，由同伴朗读；第二遍再核对关键词。听到一个熟悉词并不意味着找到了答案，还要判断谁说了什么、建议是否被接受。口头回应时用完整短句说明自己的选择，并给出一个与对话一致的理由。不要把听前预测当成听后事实，也不要因为人物语气友好就推断他们已经达成了所有安排。",
      2: "阅读先用标题预测内容，再用段落中的动作、转折和结果检查预测。区分文章主旨、明确细节与推断：主旨要覆盖全文，细节可以回到原句定位，推断则需要把文本证据与合理解释连接起来。下面的短文为原创演示文章。先找主人公起初的想法，再标出促使想法变化的事件，最后解释结尾的反思怎样回扣开头。不要把一个例子扩大成所有人的共同经历。",
      3: "本节从完整语境中观察结构，而不是只记住一个名称。先圈出例句中的目标形式，指出它修饰或补充说明的对象，再尝试改写成意思相近的完整句。对比正确句与易错句时，必须说清错误改变了哪一种语法关系；只说“读起来不顺”不能帮助修改。最后用本单元的新情境写两句自己的句子，检查意思是否清楚，再检查词形、时态和逻辑主语。",
      4: "互动交流要先回应对方已经表达的意思，再补充自己的观点。复述时可以使用 So you mean ...，追问时用 Could you explain ...，表达不同看法时先说明依据。下面的对话围绕本单元具体事件展开。练习时两人交换角色：一人提出追问，一人用一个文本细节回答。避免只背一段独白而不听问题，也不要把自己的观点放进对方口中。谈话结束前用一句话确认下一步或共同理解。",
      5: "写作先确定读者和目的，再安排信息。本节的原创范文展示了主题内容如何通过具体细节展开。阅读时标出开头交代的情境、中间最重要的事件或理由，以及结尾表达的感受或判断。修改时先检查内容是否能回答写作任务，再检查段落衔接和语法。用词准确比堆砌形容词更重要；每一个评价都应有可观察的动作、对话或事实支撑，而不是连续使用 interesting、good 或 great。",
      6: "自评不是重新背诵一遍单词表，而是检查能否在新情境中调动语言。先独立完成下面的纠错、释义和表达任务，再说明每一项选择的理由。把错误分成词义、搭配、句法和篇章四类，找出你真正需要复习的部分。遇到不确定的句子，回到本单元例句进行比较。能认出正确句和能自己写出正确句是两种能力；完成选择题后，还应做一次不看答案的口头或书面表达。",
      7: "项目学习需要一个清楚的作品和可以检查的标准。本节任务不是收集越多信息越好，而是让听众理解一个主题。先确定作品用途和读者，再分配搜集、写作、校对与展示的工作；所有成员都应能解释作品的关键内容。把同伴反馈转成具体修改，例如补充一个原因、删除无依据的概括或改写不清楚的句子。展示后用一条证据说明作品改进了什么，而不是仅报告大家完成了分工。",
      8: "观看短片时同时关注画面、字幕和旁白。画面能显示动作与顺序，字幕可能概括主题，旁白则补充画面中看不到的原因；三者并不总是逐字重复。下面提供本地演示短片的原创分镜脚本，可在没有音频的情况下先读画面说明，再用旁白核对理解。练习时先描述你看见什么，再解释其含义，避免把自己的推测当成镜头明确展示的事实。最后用三句话复述从开头到结尾的变化。"
    }[section]
    if section == 1:
        summary=f"在 {theme} 的原创对话中听取场景、安排和理由，练习询问、回应与解释自己的选择。"
        evidence=f"本单元听说场景是 {u['place']}。先完成信息表：人物是谁、正在解决什么问题、提出了哪些建议、最终准备怎样做。对话中的具体证据包括：{listening_detail} 再用它检查你记录的关键词是否属于同一件事。听力记录可以简写，但复述时要恢复完整逻辑，不要把建议写成已经发生的结果。"
        compare=f"容易混淆的不是两个孤立单词，而是信息的确定程度。{LISTENING_INFERENCES[unit_index]} 把人物的计划、解释与最终行动分别写在三栏中；如果对话只说 could 或 may，就不要在答案里改成肯定发生。语言上还需留意：{u['mistake']} 用同一主题的新句子举例，比脱离语境反复抄写单词更能检查理解。"
        apply=f"角色任务：两人重组关于 {u['place']} 的对话。一人保留原来的目标，另一人更换一个条件，例如时间、参与者或可用材料；先提出一个清楚的问题，再给出有理由的回应。可参考的表达是：{u['grammar_good']}\n\n以下是同一组说话人的原创角色练习示例，保留本节场景并增加一个明确条件，不需要先阅读其他板块：\n{LISTENING_PRACTICE[unit_index]}"
        blocks=[block('explanation','听前定位与原创对话',method+'\n\n'+u['dialogue']),block('diagram','信息路径：场景—建议—理由',evidence),block('comparison','区分听到的信息与自己的推测',compare),block('application','双人角色任务',apply)]
        choice_prompt=f"根据本单元原创听说材料，哪一项与讨论的具体安排一致？"
        answers=[listening_detail,"The speakers decide to ignore the other person's question.","The discussion contains no practical suggestion.","Everyone has exactly the same experience and opinion."]
        jprompt="听说记录中，人物提出的建议可以不加区分地写成已经发生的事实。"
        janswer="错误"; jexp="建议、计划和已发生事件的语气与时态不同，记录时应保持原来的确定程度。"
        short=f"请用两句英文概括 {u['place']} 中人物讨论的目标和一个理由。"; shortans=listening_detail
        key=u['dialogue'].split('\n')[0].split(': ',1)[1]
        task=f"围绕 {u['place']} 提出一个请求，回应后补充一个具体理由。参考：{listening_detail}"
    elif section == 2:
        summary=f"阅读原创短文 {u['reading_title']}，跟踪人物想法的变化，并区分主旨、细节和有证据的推断。"
        evidence=f"文章的证据链可以画成三步：{u['reading_evidence']}。每一个箭头都需要用文本中的动作或话语说明，不能只凭主题名称猜测。核心细节是：{u['reading_detail']} 用这条细节回答“发生了什么”，再用文章结尾回答“人物学到了什么”。若两个选项都涉及主题，应优先选择能覆盖人物起点、事件和结果的表达，而不是范围过大或只说一段内容的表达。"
        compare=f"本文主旨是：{u['reading_main']} 这是对全文的概括；它与一条事实细节不同，也比“这是一篇关于 {subject} 的文章”更具体。合理推断是：{u['inference']} 推断需要证据但不是原句照抄。评价人物时先指出文本行为，再提出解释，不能因为文章主题积极就假定人物没有犹豫、没有成本或获得了奖励。"
        apply=f"用以下顺序做一次英文复述：人物最初的想法 → 促使想法变化的细节 → 最后的理解。复述时可使用 at first、however、by the end 等衔接语，但必须让连接词反映真实关系。下面是同主题写作拓展材料，事件与本节阅读一致，可帮助比较叙述角度；它不是阅读题的新增证据：\n\n{u['writing']}\n\n最后给短文换一个标题，并用一个文本细节解释新标题为什么合适。"
        blocks=[block('explanation',u['reading_title']+' · 原创阅读',method+'\n\n'+u['reading']),block('diagram','情节与证据链',evidence),block('comparison','主旨、细节与推断',compare),block('application','有证据的复述',apply)]
        choice_prompt="哪一项最能概括这篇原创短文的主旨？";answers=[u['reading_main'],"Every person in the community has the same opinion.","The main character wins a large prize at the end.","The events show that careful observation is unnecessary."]
        jprompt="阅读推断可以完全离开文章细节，只根据单元标题作答。";janswer="错误";jexp="推断应由具体行为、话语或结果支持，标题只能提供主题线索。"
        short="请用英文列出一条支持主旨的具体细节。";shortans=u['reading_detail'];key=u['reading_main'];task=f"换一个情境后仍用事实支持观点。可参照证据链：{u['reading_evidence']}。"
    elif section == 3:
        summary=f"在 {theme} 情境中学习{u['grammar']}，理解语法关系，并用对比和改写检查自己的表达。"
        evidence=f"语法关系图的中心句是：{u['grammar_good']} 先找句子主干，再标出目标结构及其说明的对象。可以把目标部分展开或改写，确认意思没有被改变。{u['grammar_text']} 将“形式、依附对象、表达作用”分别放进三格，遇到新句子时按同样顺序分析，而不是只看是否出现 to 或 -ing 就直接下结论。"
        compare=f"正确示例：{u['grammar_good']}\n易错示例：{u['grammar_bad']}\n\n{u['grammar_reason']} 修改完成后还要检验主题意思有没有变化。错误句不是为了机械记忆一个禁用词，而是帮助发现词形、结构和语义之间的联系。请再写一个与 {u['place']} 相关的新例句，指出目标结构起什么作用，并用中文解释句意。"
        apply=f"迁移任务：阅读下面的原创情境，然后用本节结构写两句补充说明。第一句描述人物、物品或行为，第二句说明理由、目的或说话人的立场；具体用途以本节语法为准。写好后交换检查，先指出逻辑关系，再提出修改。下面是同主题应用对话，作为原创拓展情境，不是本节语法题所依赖的额外前文：\n\n{u['talk']}\n\n参考句：{u['grammar_good']} 如果你的新句子与这个例句结构不同，应说明差别，而不必强行把所有句子改成同一种形式。"
        blocks=[block('explanation',u['grammar'],method+'\n\n'+u['grammar_text']),block('diagram','结构—对象—作用',evidence),block('comparison','正确句与易错句',compare),block('application','放进新的主题情境',apply)]
        choice_prompt=f"哪一句正确使用了本节的{u['grammar']}？";answers=[u['grammar_good'],u['grammar_bad'],"Yesterday they are discuss the idea.","The visitors was ask a question."]
        jprompt=f"分析本节语法时，除了目标形式，还需要判断它与句子其他成分的关系。";janswer="正确";jexp=u['grammar_reason']
        short="请解释本节正确示例的意思，并指出目标结构的作用。";shortans=u['grammar_good']+' '+u['grammar_reason'];key=u['grammar_good'];task=f"围绕 {u['place']} 写一个新句子，使用{u['grammar']}并说明其作用。"
    elif section == 4:
        summary=f"围绕 {theme} 练习追问、解释与回应，用具体细节支持观点，并在对话中确认共同理解。"
        evidence=f"本节互动路径不是轮流背诵，而是“听清问题 → 回应问题 → 提供依据 → 确认理解”。讨论中的可用证据是：{talking_detail} 可表达的理解是：{u['reading_main']} 回答追问时从证据出发；如果问题涉及文本没有说明的内容，可以说 The text does not tell us ...，然后把话题拉回已经知道的事实，保持对话真实。记录同伴追问的关键词，并检查你的回答是否正面回应了问题。"
        compare=f"对话中的赞同、追问与不同意见应当区分。I see what you mean. 表示理解对方，不一定是完全同意；Could you explain why ...? 是索取理由，不是直接否定。把本节对话的具体意思讲清楚：{TALKING_INFERENCES[unit_index]} 若只重复主题词 {theme}，听者仍不知道你依据了什么。语言方面还应检查：{u['mistake']} 再用一个完整句替换含混的评价。"
        apply=f"小组交流任务：一位同学负责提问，一位说明自己的观点，第三位记录双方实际使用的证据。交换角色后加入一个新的追问，要求说话人解释一个限制或另一种可能。下面明确标为同主题项目拓展任务，可在本节对话结束后用于新的讨论；它不是原对话已经发生的事件：\n\n{u['project']}\n\n结束时用一句英文总结已经达成的理解，并提出仍需了解的一个问题。"
        blocks=[block('explanation','回应与追问 · 原创对话',method+'\n\n'+u['talk']),block('diagram','互动中的证据路线',evidence),block('comparison','理解、赞同与追问',compare),block('application','三人对话任务',apply)]
        choice_prompt="在本单元讨论中，哪一句最适合作为有具体依据的回应？";answers=[talking_detail,"I agree because everyone must think the same.","There is no need to explain any reason.","The topic is interesting, so all guesses are facts."]
        jprompt="说 I see what you mean. 就一定表示完全赞同对方。";janswer="错误";jexp="这句话首先表示理解对方意思；是否同意还应看后面的解释。"
        short="请针对本单元故事提出一个追问，并给出有依据的回答。";shortans="Example question: What detail supports your view? Answer: "+talking_detail;key=u['reading_main'];task=f"用 Could you explain why ...? 追问 {subject} 的一个具体细节，并用原文信息回答。"
    elif section == 5:
        summary=f"阅读 {u['writing_title']}，学习用具体细节组织 {theme} 写作，并完成一段自己的原创表达。"
        evidence=f"范文可以按“情境或立场 → 关键细节 → 结果或反思”整理。它围绕 {u['place']} 展开，关键内容是：{u['reading_detail']} 结尾的中心意思是：{u['reading_main']} 每一段应承担不同作用，不要把结尾写成开头的简单重复。选择连接词之前先说清两句之间是时间、原因、转折还是递进关系；只有关系明确，衔接词才真正帮助读者理解。"
        compare=f"把空泛评价改成有细节的表达。例如只写 It was good. 没有说明为什么，而写出人物的行动和影响，读者就能判断事件的意义。当前主题可使用的具体理解是：{u['inference']} 语法检查还应留意：{u['grammar_reason']} 修改时先处理观点与事实是否一致，再检查单词形式；不要因为句子更长就认为表达一定更好。"
        apply=f"写作任务：{u['workbook']}\n\n完成初稿后用三项检查表自查：读者能否找到主题句？至少两个具体细节是否支持主题？最后一句是否给出由内容推得的感受、判断或下一步？再请同伴指出一处意思最清楚和一处需要补充的地方。参考语言：{u['grammar_good']} 可以使用同一种结构，但例子和表达应来自你自己的写作情境。"
        blocks=[block('explanation',u['writing_title']+' · 原创范文',method+'\n\n'+u['writing']),block('diagram','段落各自承担什么作用',evidence),block('comparison','具体细节与空泛评价',compare),block('application','写作与修改清单',apply)]
        choice_prompt="哪一项最适合作为本节写作的中心意思？";answers=[u['reading_main'],"Use as many difficult adjectives as possible without evidence.","A piece of writing does not need a clear reader or purpose.","Long sentences are always better than short sentences."]
        jprompt="写作修改只需要检查拼写，不必检查细节是否支持中心意思。";janswer="错误";jexp="内容和组织应先检查，拼写只是语言检查的一部分。"
        short=f"请为 {u['writing_title']} 写一句能回扣内容的结尾。";shortans=u['reading_main'];key=u['writing'].split('\n\n')[-1];task=f"按情境、细节、反思三部分写一段关于 {subject} 的短文。"
    elif section == 6:
        summary=f"综合检查 {theme} 的词汇、{u['grammar']}与篇章理解，并把错误转成具体复习任务。"
        evidence=f"把本单元整理成三层知识图：主题词汇用于谈论 {subject}，句法结构用于表达关系，文章证据用于支撑观点。词汇示例是 {u['vocab'][0][0]} 和 {u['vocab'][1][0]}，关键搭配有 {u['collocation']}。结构示例是：{u['grammar_good']}。篇章核心是：{u['reading_main']} 三层之间可以互相检查，但不能用记住一个词代替理解一整段话。把一个关键词放回原句，再口头解释它与全文观点的关系。"
        compare=f"本节自检材料：{u['assess']}\n\n请先解释每句意思，再判断目标结构的作用。词汇方面需辨析：{u['mistake']} 语法方面要能说明：{u['grammar_reason']} 如果你只是在选项中认出了正确句，还要遮住选项重新表达一次；如果自己写错了，标出错误类型并写出一个新例句，而不是只抄一遍标准答案。"
        apply=f"综合输出任务：用三到四句英文说明你对 {subject} 的理解。第一句给观点，第二句给具体细节，第三句解释细节为什么支持观点；必要时再补充一个限制。可用的细节是：{u['reading_detail']}。再完成下面的原创迁移练习：\n\n{u['workbook']}\n\n自评分开记录“我能解释的内容”和“我仍需查证的表达”，据此选择下一张闪卡。"
        blocks=[block('explanation','自评应该检查什么',method+'\n\n'+u['grammar_text']),block('diagram','词汇—结构—篇章',evidence),block('comparison','认出答案与独立表达',compare),block('application','新的语境中再表达',apply)]
        choice_prompt="哪一句可以作为本单元语法的正确自检例句？";answers=[u['grammar_good'],u['grammar_bad'],"They was thinking yesterday.","She have wrote it last week."]
        jprompt="完成自评后，最好根据错误类型安排复习，而不是把所有内容等量重抄。";janswer="正确";jexp="词义、搭配、句法和篇章错误需要不同的练习，分类能让复习更有针对性。"
        short="请用一条具体细节支持本单元故事的中心意思。";shortans=u['reading_detail']+' '+u['reading_main'];key=u['assess'];task=f"用 {u['vocab'][0][0]} 和本单元目标结构各写一句，并说明句意。"
    elif section == 7:
        summary=f"完成 {theme} 主题作品，明确读者、证据、分工与修改标准，把语言知识用于可展示的任务。"
        evidence=f"项目路径为“确定问题 → 制作初稿 → 同伴测试 → 根据反馈修改”。当前作品与 {u['place']} 有关，重点不是装饰，而是让读者看懂：{u['reading_main']} 可以利用的具体情境是：{u['reading_detail']} 检查每一部分是否服务于作品目的，并记录一处实际修改以及修改理由。小组中每个人都应能解释一条核心信息，而不是只有写作者能够回答问题。"
        compare=f"任务完成与作品有效并不是同一件事。交齐资料说明完成了步骤，读者能理解并找到依据才说明表达有效。当前主题中容易过度概括的地方是：{u['inference']} 因此展示时应分清你观察到的事实、人物的观点和小组的解释。语言检查可从这一条易错点开始：{u['mistake']} 让同伴提出一个你没有预先准备的问题，再观察作品能否帮助作答。"
        apply=f"展示示例材料：\n\n{u['writing']}\n\n按本节项目要求改写这份材料，让它成为你的作品的一部分。注意示例只提供可观察的情境，不应冒充真实采访或真实调查。展示后收集两条具体反馈，分别说明“哪一处信息不清楚”和“怎样修改更有用”。最后用一句英文介绍你做出的一个修改，并指出它怎样帮助读者理解 {subject}。"
        blocks=[block('explanation','项目任务书',method+'\n\n'+u['project']),block('diagram','从任务到修改',evidence),block('comparison','做完与说清楚的区别',compare),block('application','展示、反馈与再设计',apply)]
        choice_prompt="根据本节项目任务，哪一项最能帮助检查作品是否有效？";answers=["Ask a partner to explain a key idea and identify the evidence supporting it.","Count the colours and ignore whether the message is clear.","Let only one group member understand the main content.","Replace all specific details with a slogan."]
        jprompt="项目展示只要画面漂亮，就不需要说明信息来源或观点依据。";janswer="错误";jexp="作品需要可理解的信息和可说明的依据；外观不能替代内容。"
        short="请用英文说明本主题项目的一个关键内容和一项修改标准。";shortans=u['reading_main']+' Check whether each claim is supported by a specific detail.';key=u['project'].split('. ')[0]+'.';task=f"为 {subject} 作品设计一个同伴能实际回答的检查问题。"
    else:
        summary=f"通过 {theme} 原创分镜学习整合画面、字幕与旁白，按证据复述短片，不把推测当成画面事实。"
        evidence=f"三幅画面的主题路线是：{' → '.join(u['scene_steps'])}。第一步交代情境，中间展示关键行动，最后揭示结果或主题。把每一幅画面能直接看到的信息写在左栏，把需要由旁白或上下文解释的意义写在右栏。可用于解释的主题句是：{u['reading_main']} 如果镜头只给出一个例子，就不能把它扩展为关于所有人的结论；复述时用具体人物和具体动作限定范围。"
        compare=f"观看任务要区分描述和解释。描述回答“画面展示了什么”，解释回答“这个细节为什么有意义”。当前故事的关键解释是：{u['inference']} 若暂时关闭旁白，只依据画面能够确认哪些内容？恢复旁白后又补充了什么？用本单元词汇复述时还需注意：{u['mistake']} 保持语言与证据一致，比把每一个镜头都赋予宏大意义更准确。"
        apply=f"配音与字幕任务：两人选择本节三幅分镜，一人用三句英文描述动作，另一人用一句主题句解释它们的联系。随后交换角色，检查画面信息与评价是否分开。可以参考下面明确标出的同主题讨论拓展；其中人物的解释可帮助练习说法，但不能当作短片画面直接展示的事实：\n\n{u['talk']}\n\n完成后让第三位同学只看字幕复述短片；如果复述与原脚本明显不同，就修改含混的主语、时间顺序或代词指向。"
        blocks=[block('explanation','原创短片分镜与旁白',method+'\n\n'+u['video']),block('diagram','三镜头叙事线',evidence),block('comparison','画面事实与意义解释',compare),block('application','配音与字幕练习',apply)]
        choice_prompt="哪一项最符合本节三镜头短片想表达的中心意思？";answers=[u['reading_main'],"Every object in a video proves the same opinion.","A subtitle can replace all observation of the images.","A viewer should add unsupported details to make the story exciting."]
        jprompt="复述短片时，画面中没有出现而只是自己猜想的信息，应当与观察到的事实区分。";janswer="正确";jexp="画面、旁白与推测属于不同信息来源，区分后才能作有依据的复述。"
        short="请用三句话概括本节短片，并写一句主题句。";shortans=' → '.join(u['scene_steps'])+'; '+u['reading_main'];key=u['reading_main'];task=f"按 {' → '.join(u['scene_steps'])} 为本节短片配三条字幕。"
    jprompt,janswer,jexp=JUDGMENTS[unit_index][section-1]
    qs=[judgement(jprompt,janswer,jexp,subject),quiz('choice',choice_prompt,answers,answers[0],f"本节证据支持：{answers[0]} 其他选项不是材料表达的内容，或把局部事实作了没有根据的扩大。",subject),quiz('short-answer',short,[],shortans,'参考答案应包含明确意思及至少一条与本节材料一致的细节；英文表达可有其他正确形式。',subject)]
    # Rotate the correct option to avoid a predictable all-A demonstration.
    rotation=(unit_index+section)%4
    qs[1]['choices']=answers[rotation:]+answers[:rotation]
    return dict(chapter_id=chapter_id,summary=summary,objectives=[f"理解本节 {theme} 的具体内容",f"在情境中使用{u['grammar']}或相关主题词汇",f"完成 {SECTIONS[section-1]} 的独立表达任务"],key_concepts=[v[0] for v in u['vocab']],blocks=blocks,flashcards=cards(u,section,key,task),quizzes=qs,diagram_steps=u['scene_steps'],diagram_focus=u['formula'])


def workbook_topic(index, chapter_id):
    u=UNITS[index]
    t=section_topic(index,6,chapter_id)
    t['summary']=f"在 {u['name']} 的新情境中综合运用词汇、语法、阅读和写作，配有可核对的答案与修改理由。"
    t['blocks'][0]=block('explanation','Workbook · 新情境练习',u['workbook']+'\n\n'+u['grammar_text'])
    t['blocks'][1]=block('diagram','综合练习的解题路线',f"先读清任务要求，再确定句子表达的是事实、建议、计划还是观点。当前单元的目标结构是{u['grammar']}，可参照：{u['grammar_good']}。词汇与搭配需要回到 {u['place']} 的具体情境判断，不能只寻找与选项重复的单词。完成后用以下细节核对主题理解：{u['reading_detail']}。最后检查你的回答是否给出依据，短文任务是否有清楚的开头、支持细节和结果。")
    t['blocks'][2]=block('comparison','答案不只是一项选择',f"本次练习应解释为什么答案成立。正确结构：{u['grammar_good']} 易错结构：{u['grammar_bad']}。{u['grammar_reason']} 同时辨析一个词汇问题：{u['mistake']}。如果你选对了答案却说不出原因，应再做一个新情境造句；如果语言形式正确但意思与材料不符，应重新定位细节，而不是继续增加形容词或连接词。")
    t['blocks'][3]=block('application','参考表达与自改',u['writing']+'\n\n这份原创参考表达展示了怎样组织内容，不是唯一标准答案。请圈出一处主题细节和一处目标结构，再写一个不同情境的版本，解释你保留和改变了什么。')
    t['quizzes'][2]['prompt']='请完成本节 Workbook 写作任务，至少使用一个目标结构，并说明其作用。'
    t['quizzes'][2]['answer']=u['writing']+' 结构参考：'+u['grammar_good']
    return t


def reference_topic(chapter_id, title, summary, parts, concepts, card_pairs, questions, steps, focus):
    return dict(chapter_id=chapter_id,summary=summary,objectives=["理解本节工具条目的组织方式","用具体句子检查词义与结构","将查阅结果用于修改一个真实表达"],key_concepts=concepts,blocks=[block(k,t,c) for k,t,c in parts],flashcards=[dict(front=f,back=b,concept=concepts[i]) for i,(f,b) in enumerate(card_pairs)],quizzes=questions,diagram_steps=steps,diagram_focus=focus)


def reference_topics():
    refs=[]
    refs.append(reference_topic('english-ref6','Notes','学习用词性、搭配、句法和上下文信息制作可复用的英语注释，而不把所有词都翻成孤立中文。',[
      ('explanation','注释应该帮助解决什么问题',"Notes 页可以帮助解释词义、文化背景和句法关系。遇到不懂的句子时，先判断困难来自哪一层：不认识单词、不了解搭配、看不清句子主干，还是缺少背景信息。例如 She kept her word. 中 word 不是单纯的“单词”，keep one's word 表示遵守承诺。注释应说明这个搭配在当前情境中的意思，并给一个可以迁移的新例句，而不是把每一个已认识的词都抄进笔记。"),
      ('diagram','从原句到可复用注释',"把注释画成“原句 → 问题 → 解释 → 新例句”。原句 She kept her word. 的问题是搭配含义，解释为“她遵守了诺言”，新例句可写 Nora kept her word and repaired the bag on Saturday. 如果困难是句法，则先划出主句，再把修饰部分单独标注。注释末尾写清你学会了什么，如 keep one's word 可以描述兑现承诺；这样复习时能够检测是否会用，而不仅是是否看过。"),
      ('comparison','词义说明与背景猜测',"注释可以帮助理解文本，但不能把无依据的文化猜测写成事实。比如一位人物在节日中点亮灯笼，并不能证明同一地区的每个人都采用相同习俗。词典义、语境义和你的推断也应分开记录。传统、饮食和称呼等背景条目，应说明适用范围；句法条目应给出恢复或改写后的句子。只有注明具体语境，注释才能服务阅读，而不是增加另一个需要死记的长列表。"),
      ('application','为一句话制作注释卡',"给句子 If possible, ask before taking a photograph. 制作注释：第一，If possible 可恢复为 If it is possible；第二，before 是介词，后面的 taking 使用动名词形式；第三，ask 的具体内容应由拍照情境补出，即先询问对方是否同意。再写新例句 If possible, speak to the stallholder after the queue becomes shorter. 最后合上解释，用自己的话说清两句的条件与行动，检查你是否真正理解了结构。注意注释中的中文说明应解释关系，不能只逐词替换；再由同伴尝试用同一结构造句。")
    ],['语境义','固定搭配','句子主干','省略恢复','适用范围','迁移例句'],[
      ('She kept her word. 中 keep her word 是什么意思？','遵守她的诺言；word 在这个搭配中不是孤立的“单词”。'),('注释为什么要保留原句？','原句提供词义和结构所需的语境，避免把一种用法无限扩大。'),('看不清长句时先找什么？','先找主句的主语和谓语，再分析修饰部分。'),('If possible 可以恢复成什么？','If it is possible。'),('个人的节日经历能代表整个文化吗？','不能；说明具体人物、活动和范围后再作解释。'),('怎样检查注释是否可复用？','不看原答案，用相同搭配或结构写一个意思清楚的新例句。')
    ],[judgement('Notes 中的文化说明可以把一个人的经历直接概括为所有人的共同习惯。','错误','需要限定人物、情境和范围。','适用范围'),quiz('choice','She kept her word. 在兑现承诺的情境中是什么意思？',['她数了单词。','她遵守了诺言。','她改变了拼写。','她忘记了名字。'],'她遵守了诺言。','keep one\'s word 是“遵守诺言”的搭配。','固定搭配'),quiz('short-answer','请为 If possible 写一个简短注释并给出完整形式。',[],'If possible 省略了 it is，完整形式是 If it is possible。','应同时给出省略关系和句意。','省略恢复')],['保留原句和问题','补充用法与范围','写新例句检验'],'原句 + 关系解释 + 新例句，而非孤立译词'))
    grammar_content='\n\n'.join(u['grammar']+'：'+u['grammar_text'] for u in UNITS)
    refs.append(reference_topic('english-ref7','Grammar','综合比较 -ing、语境省略、不定式以及情态动词和过去将来时，按句中作用判断结构。',[
      ('explanation','按功能整理五类结构',grammar_content),
      ('diagram','先找主干，再分析附加关系',"综合语法分析可以按四步进行：找出主句主语和谓语，确定待分析的形式，指出它与哪个成分有关，最后解释它表达的意义。例如 Seeing the queue, Maya offered to help. 中 Seeing 的逻辑主语是 Maya，to help 表达 offered 后的动作内容；The first student to notice the fault asked a question. 中 to notice 修饰 student。形式相似不代表功能相同，分析时要回到完整句子，而不是用单一标签替代句意。"),
      ('comparison','形式变化与意思变化',"比较 The story is moving. 和 The students were moved.：前句说明故事使人感动的性质，后句说明学生的感受。再比较 She said she would help. 与 She helped.：前句报告过去说过的后续打算，后句陈述行动已经发生。语法选择会改变意思。纠错时不仅检查哪个形式更熟悉，还要说明修改是否保留了原来要表达的关系。遇到没有明确语境的题目，应指出多种形式可能对应不同解释，而不机械套用一个时态。"),
      ('application','综合改写与解释',"改写任务一：The children who are carrying lanterns are waiting. 可改为 The children carrying lanterns are waiting.，后置分词短语保留主动修饰关系。任务二：If it is possible, ask first. 可简化为 If possible, ask first.。任务三：The team tested the model because they wanted to find faults. 可改为 The team tested the model to find faults.。每次改写后写一句解释，指出省去了什么、保留了什么，不把改写看成单纯的单词替换。还可以反向恢复完整句，检查修饰对象和逻辑主语是否保持一致，确认句意没有被省略操作改变。")
    ],['-ing定语','-ing状语','语境省略','不定式定语','不定式目的','过去将来时'],[
      ('the children carrying lanterns 中 carrying 修饰谁？','修饰 children，表示孩子主动提着灯笼。'),('Seeing the queue, Maya offered to help. 中谁 seeing？','Maya，分词短语的逻辑主语与主句主语一致。'),('I would love to. 省略了什么？','省略前文已经明确的动词短语，通常保留 to。'),('the first student to notice the fault 中不定式的作用？','后置修饰 student，说明第一个发现问题的学生。'),('The team repeated the test to find faults. 中 to find 的作用？','说明重复测试的目的。'),('She said she would help. 是否证明后来帮助了？','不证明；它报告从过去看未来的打算，实际结果需另外交代。')
    ],[judgement('现在分词作状语时，通常要检查其逻辑主语与主句主语是否一致。','正确','一致的逻辑主语有助于避免悬垂分词。','-ing状语'),quiz('choice','哪一句用不定式明确表达目的？',['The model is useful.','She was waiting.','We tested the model to find faults.','They had a model.'],'We tested the model to find faults.','to find faults 回答测试的目的。','不定式目的'),quiz('short-answer','将 If it is possible, ask first. 改为省略句，并说明删去了什么。',[],'If possible, ask first. 删去了 it is，条件含义不变。','完整形式必须可由语境恢复。','语境省略')],['识别句子主干','判断目标结构关系','核对形式与句意'],'同一形式可能有不同功能；语法要回到完整句子'))
    wordlist='\n'.join(f"Unit {i+1} {u['name']}: "+'; '.join(w+' — '+meaning for w,meaning in u['vocab']) for i,u in enumerate(UNITS))
    refs.append(reference_topic('english-ref8','Words and Expressions','按五个单元主题整理词汇、词性和搭配，并把单词用于具体而完整的表达。',[
      ('explanation','五个主题词群',wordlist+'\n\n这些条目是用于演示的主题词表。查阅后应回到句子判断词义，不把中文译义当成在所有语境下都不变的答案。'),
      ('diagram','从词到搭配再到句子',"主题词表可以按“词形与词性 → 常见搭配 → 当前语境的句子”来使用。以 responsibility 为例，先确认它是名词，再记录 take responsibility for ...，最后写 Maya took responsibility for the mistake and corrected the label.。另一个例子是 reliable power supply，reliable 修饰名词短语，不能随意换成名词 reliability。词表负责提供线索，完整句子负责显示用法，口头或书面迁移负责检查你是否能够主动表达。"),
      ('comparison','相近词形不能直接互换',"比较 tradition 与 traditional、culture 与 cultural、patient 与 patience、reliable 与 reliability。这些词意义有关，但词性和句中位置不同。a cultural exchange 需要形容词修饰 exchange；be patient with a reader 中 patient 是表语；show patience 中 patience 是名词。学习词族时不要只在两个词后面写相同中文，而要各保留一个句子，指出哪个位置需要名词、哪个位置需要形容词。再比较词尾变化和句中的连接方式，检查词性与语法结构是否配合。"),
      ('application','五句主题表达',"请各写一句关于节日、志愿服务、文化交流、观测任务和修理活动的英文。参考：We decorated the square with paper lanterns. Maya showed patience with a young reader. The family adapted the recipe to local ingredients. The team collected evidence before changing the design. Sam could not afford to replace the bag that week. 写完后给搭配加下划线，再换掉一个条件重新表达，检查句子是否仍然自然且意思清楚。五句表达完成后，遮住英文只看中文情境再次表达；若只记得原句顺序而不能换主语或时间，说明还需要迁移练习。")
    ],['celebration','responsibility','cultural exchange','reliable','afford to','词性转换'],[
      ('celebration 的词性和一个搭配？','名词；a community celebration。'),('“承担某事的责任”怎样表达？','take responsibility for something。'),('文化交流的常见表达？','cultural exchange；cultural 是形容词。'),('“可靠的电力供应”怎样表达？','a reliable power supply。'),('afford 后怎样接动词？','常用 afford to do，如 cannot afford to replace the bag。'),('为什么词族要各保留例句？','例句能显示词性和搭配差别，避免只记相同中文译义。')
    ],[judgement('意思相关的名词和形容词在句中任何位置都能直接互换。','错误','词性影响句中位置和搭配。','词性转换'),quiz('choice','哪一项是合适的表达？',['a culture exchanging of','a cultural exchange','a culturally of exchange','a cultures exchanging of'],'a cultural exchange','cultural 是修饰 exchange 的形容词。','cultural exchange'),quiz('short-answer','请用 afford to 写一个完整句子。',[],'Sam could not afford to replace the bag that week.','主语、谓语和不定式补足内容应清楚，其他正确例句也可。','afford to')],['确定词性与语境','积累常用搭配','用完整句主动表达'],'单词 → 搭配 → 句子：用法比孤立译义更具体'))
    refs.append(reference_topic('english-ref9','Vocabulary','学习按词义、词族、搭配和语境建立词汇联系，并用检索与主动回忆检查掌握度。',[
      ('explanation','词汇不是一个译义列表',"一个词条至少包括词形、读音线索、词性、常见义和搭配。在阅读中遇到 value，应先判断它在当前句子里是名词“价值”还是动词“重视”。The value of a useful skill is easy to overlook. 中 value 是名词；We value your help. 中 value 是动词。记录词汇时保留一个短例句，并标出与这个词经常一起出现的成分。知道中文意思是起点，能判断语境并主动使用，才说明学习向前推进了一步。"),
      ('diagram','词汇网络的四个节点',"把一个词放在四个节点之间：主题、词族、搭配和例句。以 adapt 为例，主题可以是迁居后的食谱变化，词族有 adaptation，搭配为 adapt something to something，例句为 The family adapted the recipe to local ingredients.。从任意一个节点都应能回到具体意思。复习时可以遮住节点做主动回忆，也可以换一个主题重新造句；如果只能认出原句，就需要再做迁移练习。"),
      ('comparison','猜词、查词与确认',"猜词依靠词形和上下文，但猜测需要核对。看到 unfamiliar ingredients，可以利用前后关于食谱的句子推断 ingredients 与做食物的材料有关；随后用词表或词典确认。不要只凭一个熟悉的词根给每个词下结论，也不要把第一个查到的义项塞进所有句子。近义词还会有搭配差别，如 earn money 与 win a prize 表达不同的获得方式，不能只因为中文都可译成“获得”就相互替换。"),
      ('application','一次可检查的词汇复习',"选择五个词：gather、patient、adapt、evidence、trust。第一轮只看英文，说出本单元语境中的意思；第二轮为每个词补出一个搭配；第三轮用两个词写一个新句子，例如 Patient volunteers gathered evidence before changing the queue system.。完成后检查词性和句意是否清楚，再与同伴互提一个问题。将不能解释的词列为下一轮复习对象，而不是因为整页都看过就把所有词标为掌握。")
    ],['语境词义','词族','搭配','主动回忆','近义辨析','迁移表达'],[
      ('We value your help. 中 value 是什么词性？','动词，表示重视或珍视。'),('adapt 的一个名词词族成员？','adaptation；记忆时应另配例句确认词性和用法。'),('“使食谱适应本地材料”怎样表达？','adapt the recipe to local ingredients。'),('主动回忆与重看词表有什么不同？','主动回忆先遮住答案尝试提取，再核对遗漏。'),('earn money 与 win a prize 为什么不能机械互换？','前者强调通过工作等挣得钱，后者表示赢得奖项，搭配和情境不同。'),('怎样检查词汇是否能迁移？','换一个合理情境写新句子，并解释词义、词性与搭配。')
    ],[judgement('从上下文猜出的词义不需要再核对。','错误','上下文推断是待核对的假设，应检查是否与整句和词条相符。','语境词义'),quiz('choice','哪一项最能检查主动使用词汇的能力？',['只数一页上有几个词。','只看中文译义。','在新情境中用词造句并检查搭配。','重复看同一句而不尝试回忆。'],'在新情境中用词造句并检查搭配。','主动使用需要在新语境中组织意义与形式。','迁移表达'),quiz('short-answer','用 adapt ... to ... 写一句关于食物或生活变化的句子。',[],'The family adapted the recipe to local ingredients.','adapt的宾语和to后的适应对象应清楚，其他正确情境也可。','搭配')],['结合上下文理解','回忆词族和搭配','在新情境中造句'],'认出词义 ≠ 主动使用；用新句子检验词汇'))
    refs.append(reference_topic('english-ref10','Irregular Verbs','用具体时态和语态区分不规则动词原形、过去式与过去分词，不把过去分词当成任何过去动作的形式。',[
      ('explanation','三列形式各自做什么',"不规则动词表通常列出原形、过去式和过去分词，例如 write—wrote—written、go—went—gone、see—saw—seen、take—took—taken、give—gave—given。一般过去时常使用过去式：She wrote a diary yesterday.。完成时通常由 have 加过去分词构成：She has written a diary.。被动语态也会使用过去分词，但还需要 be 等结构：The note was written yesterday.。不能因为句子在谈过去，就一律选择第三列。第三列可以参与多种结构，但必须与完整句子中的助动词和语义关系配合。"),
      ('diagram','按句子结构选形式',"先看句子是否已有助动词，再决定动词形式。Yesterday Sam went to the repair corner. 没有完成时助动词，过去动作使用 went。Sam has gone to the repair corner. 有 has，使用过去分词 gone。The bag was taken to the repair corner. 使用 was taken 表达被动。画出“时间线索 → 助动词 → 语态关系”的检查路线，可以把不规则表与实际语法连接起来；表格记忆应服务于句子，而不是只按节奏背三列。每次选择后都要说清使用这一列的结构依据。"),
      ('comparison','几个常见混淆',"比较 She saw the notice. 与 She has seen the notice.，前句叙述过去发生的事，后句使用完成时。再比较 They made a lantern. 与 The lantern was made from used paper.，第二句把 lantern 作为主语并表达被动关系。某些动词三种形式相同，如 put—put—put，但时态仍由完整结构和语境确定。另一些过去式与过去分词相同，如 buy—bought—bought；形式相同不代表两列的功能没有区别。先找结构，再选形式，能够减少只凭词形印象作答的错误。"),
      ('application','把三列放进本单元故事',"填空并解释：Yesterday Lin ___ a diary. 答案 wrote，因为 yesterday 定位过去叙述；Lin has ___ a diary about the lantern evening. 答案 written，因为 has 后需要过去分词；The invitation was ___ by Lin. 答案 written，因为这是被动结构。再练习 buy—bought—bought、bring—brought—brought、find—found—found、keep—kept—kept。为其中两个动词各写一个过去时句和一个完成时句，并指出你依据的结构线索。互改时先给助动词加圈，再给实义动词加下划线；如果句中没有助动词，就结合时间状语和事件顺序检查是否需要一般过去时。")
    ],['动词原形','一般过去式','过去分词','完成时','被动语态','不规则词族'],[
      ('write 的三种基本形式？','write—wrote—written。'),('Yesterday she ___ a diary. 用 write 的哪种形式？','wrote，一般过去时。'),('She has ___ a diary. 应填什么？','written，has 后使用过去分词。'),('The note was ___ by Maya. 用 write 的哪种形式？','written，was written 是被动结构。'),('put 三种形式相同，是否说明没有时态差别？','不是；完整结构与上下文仍然决定时态和语态。'),('怎样把三列表迁移到表达中？','为同一动词写过去时、完成时或被动句，说明选择形式的依据。')
    ],[judgement('只要句子提到过去，就应当选择动词表的过去分词一列。','错误','一般过去时通常用过去式；过去分词需要相应的完成时、被动等结构。','过去分词'),quiz('choice','She has ___ the invitation. 选择 write 的合适形式。',['write','wrote','written','writing'],'written','has后需要过去分词written。','完成时'),quiz('short-answer','用 go 的过去式和过去分词各写一个完整句子。',[],'Sam went to the repair corner yesterday. Sam has gone to the repair corner.','went用于一般过去时；gone与has构成完成时。','不规则词族')],['找时间与助动词','区分过去式和分词','核对时态与语态'],'write—wrote—written；has written / was written'))
    return refs


def validate(data, source):
    parents={c.get('parent_id') for c in source['chapters'] if c.get('parent_id')}
    leaves={c['chapter_id'] for c in source['chapters'] if c['chapter_id'] not in parents}
    assert {x['chapter_id'] for x in data['topics']}==leaves
    assert len(data['topics'])==len(leaves)==50
    for t in data['topics']:
        assert len(t['objectives'])==3 and len(t['key_concepts'])==6
        assert len(t['blocks'])==4 and {b['block_type'] for b in t['blocks']}=={'explanation','diagram','comparison','application'}
        assert len(t['flashcards'])==6 and len(t['quizzes'])==3
        assert len(t['diagram_steps'])==3 and all(len(s)<=18 for s in t['diagram_steps'])
        assert len(t['diagram_focus'])<=70
        for b in t['blocks']:
            cn=len(re.findall(r'[\u4e00-\u9fff]',b['content']))
            words=len(re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?",b['content']))
            assert cn>=100 or words>=50, (t['chapter_id'],b['title'],cn,words)
        for q in t['quizzes']:
            assert q['prompt'] and q['answer'] and q['explanation']
            if q['choices']: assert q['answer'] in q['choices'], (t['chapter_id'],q)
        assert len({c['front'] for c in t['flashcards']})==6


def main():
    sources=json.loads((ROOT/'Resources/Data/sources.json').read_text())
    source=next(s for s in sources if s['summary']['book_id']==BOOK_ID)
    topics=[section_topic(i-1,j,f'english-c{i}-s{j}') for i in range(1,6) for j in range(1,9)]
    topics += [workbook_topic(i-1,f'english-ref{i}') for i in range(1,6)]
    topics += reference_topics()
    data={'book_id':BOOK_ID,'version':2,'topics':topics}
    validate(data,source)
    target=ROOT/'Resources/Data/MockBooks'/f'{BOOK_ID}.json'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print(f'{target.name}: {len(topics)} topics, {sum(len(t["blocks"]) for t in topics)} blocks, {sum(len(t["flashcards"]) for t in topics)} flashcards, {sum(len(t["quizzes"]) for t in topics)} quizzes; validation passed')

if __name__=='__main__': main()
