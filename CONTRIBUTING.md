# Contributing to Neuropilot

Thank you for your interest in contributing to Neuropilot! This document provides guidelines for contributing to our neuro-inclusive executive function companion.

## 🌟 Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

### Our Values
- **Neurodiversity-Affirming**: We celebrate neurological differences and design for diverse cognitive styles
- **Accessibility-First**: All contributions should consider accessibility and inclusive design
- **Evidence-Based**: Features should be grounded in research and user feedback
- **Privacy-Respecting**: User data protection is paramount
- **Collaborative**: We value diverse perspectives and constructive feedback

## 🚀 Getting Started

### Prerequisites
- **Technical Skills**: Familiarity with Flutter/Dart, Python, or relevant technologies
- **Understanding**: Basic knowledge of executive function challenges and neurodiversity
- **Tools**: Git, GitHub account, development environment setup

### First-Time Contributors
1. **Explore the codebase**: Read the [README.md](README.md) and [Architecture Documentation](docs/ARCHITECTURE.md)
2. **Set up development environment**: Follow the [Development Setup Guide](README.md#development-setup)
3. **Find a good first issue**: Look for issues labeled `good-first-issue` or `help-wanted`
4. **Join the community**: Introduce yourself in discussions or issues

## 📋 How to Contribute

### Types of Contributions

#### 🐛 Bug Reports
Help us improve by reporting bugs:
- **Search existing issues** first to avoid duplicates
- **Use the bug report template** when creating new issues
- **Provide detailed information**: steps to reproduce, expected vs actual behavior
- **Include context**: device, browser, environment details

#### ✨ Feature Requests
Suggest new features that support executive function:
- **Check existing feature requests** to avoid duplicates
- **Use the feature request template**
- **Explain the problem**: What executive function challenge does this address?
- **Describe the solution**: How would this feature help users?
- **Consider alternatives**: What other approaches might work?

#### 📚 Documentation
Improve our documentation:
- **Fix typos and errors**
- **Add missing information**
- **Improve clarity and accessibility**
- **Create tutorials and guides**
- **Update outdated content**

#### 🔧 Code Contributions
Contribute code improvements:
- **Bug fixes**: Resolve reported issues
- **Feature implementation**: Build new functionality
- **Performance improvements**: Optimize existing code
- **Accessibility enhancements**: Improve inclusive design
- **Test coverage**: Add or improve tests

## 🔄 Development Workflow

### Branch Strategy
We use a multi-environment branching strategy:

```
main (production) ← staging ← dev ← feature branches
```

### Step-by-Step Process

#### 1. Fork and Clone
```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/your-username/neuropilot.git
cd neuropilot

# Add upstream remote
git remote add upstream https://github.com/original-owner/neuropilot.git
```

#### 2. Create Feature Branch
```bash
# Update your local dev branch
git checkout dev
git pull upstream dev

# Create feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/issue-number-description
```

#### 3. Make Changes
```bash
# Make your changes
# Follow coding standards (see below)
# Add tests for new functionality
# Update documentation as needed
```

#### 4. Test Your Changes
```bash
# Run deployment validation (checks Dockerfile, requirements, workflows)
python test_deployment_fix.py

# Run backend tests
python -m pytest tests/

# Run frontend tests
cd frontend/flutter_neuropilot
flutter test

# Run linting
flutter analyze
black . --check
flake8 .

# Test locally
./scripts/test_local.sh
```

#### 5. Commit Changes
```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: add voice mode timeout configuration

- Add timeout setting for voice mode sessions
- Implement user-configurable timeout values
- Add validation for timeout ranges
- Update settings UI with timeout controls

Closes #123"
```

#### 6. Push and Create PR
```bash
# Push to your fork
git push origin feature/your-feature-name

# Create pull request
gh pr create --base dev --title "feat: add voice mode timeout configuration"
```

### Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples**:
```
feat(voice): add real-time voice mode with Gemini Live

fix(auth): resolve Firebase token refresh issue

docs: update deployment guide with multi-environment setup

test(agents): add unit tests for task atomization agent
```

## 🎨 Coding Standards

### General Principles
- **Accessibility**: Follow WCAG 2.1 AA guidelines
- **Performance**: Optimize for low-end devices and slow networks
- **Security**: Never commit secrets or sensitive data
- **Maintainability**: Write clear, self-documenting code
- **Testing**: Include tests for new functionality

### Flutter/Dart Standards
```dart
// Use descriptive names
class TaskPrioritizationScreen extends ConsumerWidget {
  const TaskPrioritizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use Riverpod for state management
    final tasks = ref.watch(tasksProvider);
    
    return tasks.when(
      data: (taskList) => _buildTaskList(taskList),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}

// Follow Flutter naming conventions
// Use const constructors where possible
// Implement proper error handling
```

### Python Standards
```python
# Follow PEP 8 style guide
# Use type hints
from typing import List, Optional
import asyncio

class TaskFlowAgent:
    """Agent responsible for task atomization and workflow management."""
    
    def __init__(self, llm_client: LLMClient) -> None:
        self.llm_client = llm_client
    
    async def atomize_task(
        self, 
        task_description: str, 
        user_context: Optional[dict] = None
    ) -> List[str]:
        """Break down a complex task into micro-steps.
        
        Args:
            task_description: The task to break down
            user_context: Optional user context for personalization
            
        Returns:
            List of micro-steps for the task
        """
        # Implementation here
        pass

# Use docstrings for all public methods
# Handle errors gracefully
# Use async/await for I/O operations
```

### Accessibility Guidelines
- **Semantic HTML**: Use proper HTML elements and ARIA labels
- **Color Contrast**: Ensure 4.5:1 contrast ratio minimum
- **Keyboard Navigation**: All interactive elements must be keyboard accessible
- **Screen Reader Support**: Provide meaningful alt text and labels
- **Focus Management**: Clear focus indicators and logical tab order

### Neuro-Inclusive Design Principles
- **Reduce Cognitive Load**: Minimize unnecessary complexity
- **Clear Visual Hierarchy**: Use consistent spacing and typography
- **Predictable Interactions**: Maintain consistent UI patterns
- **Customizable Interface**: Allow users to adjust settings for their needs
- **Error Prevention**: Provide clear validation and helpful error messages

## 🧪 Testing Guidelines

### Test Coverage Requirements
- **New features**: Must include unit tests
- **Bug fixes**: Must include regression tests
- **Critical paths**: Require integration tests
- **UI components**: Should include widget tests
- **Deployment changes**: Must pass deployment validation script

### Pre-Deployment Validation
Before deploying or creating pull requests that affect deployment:

```bash
# Run the deployment validation script
python test_deployment_fix.py

# This script validates:
# - Dockerfile syntax and build requirements
# - API server import integrity
# - Requirements.txt package availability
# - Deployment workflow YAML structure
```

### Testing Best Practices
```dart
// Flutter widget tests
testWidgets('TaskPrioritizationScreen displays tasks correctly', (tester) async {
  // Arrange
  final mockTasks = [
    Task(id: '1', title: 'Test Task', priority: 'high'),
  ];
  
  // Act
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasksProvider.overrideWith((ref) => AsyncValue.data(mockTasks)),
      ],
      child: MaterialApp(home: TaskPrioritizationScreen()),
    ),
  );
  
  // Assert
  expect(find.text('Test Task'), findsOneWidget);
  expect(find.text('high'), findsOneWidget);
});
```

```python
# Python unit tests
import pytest
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_atomize_task_returns_micro_steps():
    # Arrange
    mock_llm = AsyncMock()
    mock_llm.generate.return_value = "1. Open document\n2. Write outline"
    agent = TaskFlowAgent(mock_llm)
    
    # Act
    result = await agent.atomize_task("Write report")
    
    # Assert
    assert len(result) == 2
    assert "Open document" in result[0]
    assert "Write outline" in result[1]
```

## 🔍 Code Review Process

### Review Criteria
- **Functionality**: Does the code work as intended?
- **Code Quality**: Is the code clean, readable, and maintainable?
- **Testing**: Are there adequate tests with good coverage?
- **Documentation**: Is the code properly documented?
- **Accessibility**: Does it follow accessibility guidelines?
- **Security**: Are there any security concerns?
- **Performance**: Is the code efficient and optimized?

### Review Guidelines
- **Be constructive**: Provide helpful feedback and suggestions
- **Be specific**: Point to exact lines and explain issues clearly
- **Be respectful**: Remember there's a person behind the code
- **Ask questions**: If something is unclear, ask for clarification
- **Suggest improvements**: Offer alternative approaches when appropriate

### Reviewer Responsibilities
- **Timely reviews**: Respond within 24-48 hours
- **Thorough examination**: Check code, tests, and documentation
- **Knowledge sharing**: Explain reasoning behind feedback
- **Mentoring**: Help contributors learn and improve

## 🚀 Release Process

### Version Numbering
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Workflow
1. **Feature freeze**: Stop adding new features
2. **Testing**: Comprehensive testing in staging environment
3. **Documentation**: Update changelog and documentation
4. **Release**: Create release branch and deploy to production
5. **Post-release**: Monitor for issues and prepare hotfixes if needed

## 🏷️ Issue Labels

We use labels to categorize and prioritize issues:

### Type Labels
- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Improvements or additions to docs
- `question`: Further information is requested

### Priority Labels
- `priority: critical`: Urgent issues affecting core functionality
- `priority: high`: Important issues that should be addressed soon
- `priority: medium`: Standard priority issues
- `priority: low`: Nice-to-have improvements

### Difficulty Labels
- `good-first-issue`: Good for newcomers
- `help-wanted`: Extra attention is needed
- `difficulty: easy`: Simple changes
- `difficulty: medium`: Moderate complexity
- `difficulty: hard`: Complex changes requiring deep knowledge

### Area Labels
- `area: frontend`: Flutter/UI related
- `area: backend`: Python/API related
- `area: agents`: AI agent functionality
- `area: voice`: Voice interaction features
- `area: accessibility`: Accessibility improvements
- `area: security`: Security-related issues

## 📞 Getting Help

### Communication Channels
- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and community discussions
- **Email**: For security issues or private matters

### Resources
- **Documentation**: [docs/](docs/) directory
- **API Reference**: [docs/API.md](docs/API.md)
- **Architecture Guide**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Deployment Guide**: [docs/DEPLOYMENT_RUNBOOK.md](docs/DEPLOYMENT_RUNBOOK.md)

### Mentorship
New contributors can request mentorship:
- **Comment on issues**: Ask for guidance on specific issues
- **Tag maintainers**: Use `@maintainer` for help
- **Join discussions**: Participate in community discussions

## 🙏 Recognition

We value all contributions and recognize contributors:
- **Contributors file**: All contributors are listed in CONTRIBUTORS.md
- **Release notes**: Significant contributions are highlighted
- **Community recognition**: Outstanding contributors may be invited to join the core team

## 📄 License

By contributing to Neuropilot, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to Neuropilot! Together, we're building a more inclusive and supportive tool for neurodivergent individuals. 🌟