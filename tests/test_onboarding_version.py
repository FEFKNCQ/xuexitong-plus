import unittest

from ui.controller import ONBOARDING_VERSION, onboarding_done


class OnboardingVersionTest(unittest.TestCase):
    def test_finished_current_guide(self):
        self.assertTrue(onboarding_done("true", ONBOARDING_VERSION))
        self.assertTrue(onboarding_done(True, str(ONBOARDING_VERSION)))   # QSettings may hand back strings

    def test_older_guide_is_shown_again(self):
        # Users from before guide versions existed have done=true and no version.
        self.assertFalse(onboarding_done("true", None))
        self.assertFalse(onboarding_done("true", 0))
        self.assertFalse(onboarding_done("true", ONBOARDING_VERSION - 1))
        self.assertFalse(onboarding_done("true", "garbage"))

    def test_not_finished(self):
        self.assertFalse(onboarding_done("false", ONBOARDING_VERSION))


if __name__ == "__main__":
    unittest.main()
